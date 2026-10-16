-- lune run tests/gear_look_cases.luau <repo>
-- What a worn kit looks like, built by the real Equipment on the real
-- fighter rig, the same way for the world, the Inventory and the Store:
--   * every gemmed piece shows its stone, in the gem's shade, glowing in its
--     element (helmet brow, both forearms, both shins, chest, shield, hilt),
--     set on the outside of the armour, with a small element effect;
--   * nothing that makes the look is a SelectionBox or a Highlight (a
--     ViewportFrame draws neither, so previews lost them), so suits and
--     skins show the same everywhere;
--   * a suit's trim is real neon strips, welded to the body (or the grip),
--     standing on its plates' outward faces, not inside them;
--   * a suit leaves stones and visors as they are, and an element doesn't
--     recolour a suit's trims;
--   * the same kit builds the same every time (the Inventory's miner is
--     the world's);
--   * first person can hold every weapon skin (ViewGrip), and a weapon with
--     no straight piece off its grip.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local Instance, CFrame, Vector3, Color3 = roblox.Instance, roblox.CFrame, roblox.Vector3, roblox.Color3
local ROOT = process.args[1] or "."

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

-- The place: the Rojo tree mounted as ModuleScripts, with stand-ins for the
-- services and systems the builder needs.
local game = Instance.new("DataModel")
local sources = {}
local function mount(dir, parent)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = parent
			mount(path, folder)
		else
			local base = name:match("^(.-)%.luau$")
			if base and not base:find("%.") then
				local script = Instance.new("ModuleScript")
				script.Name = base
				script.Parent = parent
				sources[script:GetFullName()] = path
			end
		end
	end
end
local function container(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
mount(ROOT .. "/src/shared", container(game:GetService("ReplicatedStorage"), "Shared"))
mount(ROOT .. "/src/server", container(game:GetService("ServerScriptService"), "Server"))
mount(ROOT .. "/src/client", container(game:GetService("StarterPlayer"), "Client"))

local signal = {
	Connect = function()
		return { Disconnect = function() end }
	end,
}
local services = {
	Players = {
		PlayerAdded = signal,
		PlayerRemoving = signal,
		GetPlayers = function()
			return {}
		end,
	},
	TweenService = {
		Create = function()
			return { Play = function() end, Cancel = function() end }
		end,
	},
	CollectionService = {
		AddTag = function(_, inst, tag)
			inst:AddTag(tag)
		end,
		RemoveTag = function(_, inst, tag)
			inst:RemoveTag(tag)
		end,
		HasTag = function(_, inst, tag)
			return inst:HasTag(tag)
		end,
		GetTagged = function()
			return {}
		end,
		GetInstanceAddedSignal = function()
			return signal
		end,
		GetInstanceRemovedSignal = function()
			return signal
		end,
	},
	HttpService = {
		GenerateGUID = function()
			return "guid"
		end,
	},
	DataStoreService = {
		GetDataStore = function()
			return {}
		end,
	},
}
local gameProxy = setmetatable({
	GetService = function(_, name)
		return services[name] or game:GetService(name)
	end,
	BindToClose = function() end,
}, {
	__index = function(_, k)
		return game[k]
	end,
})
roblox.implementMethod("Model", "GetPivot", function(m)
	local root = m:FindFirstChild("HumanoidRootPart")
	return if root then root.CFrame else CFrame.new()
end)
-- (Moves every part with the root, as welds would.)
roblox.implementMethod("Model", "PivotTo", function(m, target)
	local root = m:FindFirstChild("HumanoidRootPart")
	local move = target * (if root then root.CFrame else CFrame.new()):Inverse()
	for _, part in m:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = move * part.CFrame
		end
	end
end)
local cache = {}
local function requireScript(script)
	local key = script:GetFullName()
	if cache[key] ~= nil then
		return cache[key]
	end
	local env = setmetatable({
		script = script,
		require = requireScript,
		game = gameProxy,
		workspace = game:GetService("Workspace"),
		Instance = Instance,
		Vector3 = Vector3,
		Vector2 = roblox.Vector2,
		CFrame = CFrame,
		Color3 = Color3,
		Enum = roblox.Enum,
		Random = roblox.Random or {
			new = function()
				return {
					NextNumber = function()
						return 0.5
					end,
					NextInteger = function(_, a)
						return a
					end,
				}
			end,
		},
		task = task,
		warn = function() end,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		UDim2 = roblox.UDim2,
		UDim = roblox.UDim,
		TweenInfo = {
			new = function()
				return {}
			end,
		},
	}, { __index = _G })
	local result = luau.load(fs.readFile(sources[key]), { debugName = sources[key], environment = env })()
	cache[key] = result
	return result
end
local systems = game:GetService("ServerScriptService").Server.Systems
local stubData = setmetatable({ CharacterChanged = signal, Changed = signal }, {
	__index = function()
		return function()
			return nil
		end
	end,
})
cache[systems.PlayerData:GetFullName()] = stubData
cache[systems.Shop:GetFullName()] = setmetatable({}, {
	__index = function()
		return function() end
	end,
})
local Equipment = requireScript(systems.Equipment)
local FighterRig = requireScript(systems.FighterRig)
local Shared = game:GetService("ReplicatedStorage").Shared
local Cosmetics = requireScript(Shared.Cosmetics)
local GemConfig = requireScript(Shared.GemConfig)
local Tags = requireScript(Shared.Tags)
local ViewGrip = requireScript(game:GetService("StarterPlayer").Client.Modules.ViewGrip)

-- A kit, and a body wearing it.
local KIT = {
	Class = "Warrior",
	Weapon = "MatrixSwords1",
	Helmet = "ArmorSkirmisherHelmet1",
	Armor = "ArmorJuggernautArmor4",
	Gloves = "ArmorSkirmisherGloves1",
	Boots = "ArmorSkirmisherBoots1",
	Shield = "ArmorSkirmisherShield1",
}
local GEMS = {
	Helmet = { Element = "Poison", Tier = "Rare" },
	Armor = { Element = "Frost", Tier = "Rare" },
	Gloves = { Element = "Fire", Tier = "Common" },
	Boots = { Element = "Shock", Tier = "Uncommon" },
	Weapon = { Element = "Fire", Tier = "Common" },
	Shield = { Element = "Frost", Tier = "Common" },
}
local function wear(gems, cosmetics, loadout)
	local body = FighterRig.build()
	body:SetAttribute("FistGrip", true)
	body.Parent = game:GetService("Workspace")
	local kit = table.clone(loadout or KIT)
	for slot, g in gems or {} do
		kit[slot .. "Gem"] = { Id = slot, Element = g.Element, Tier = g.Tier, Size = 8, Clarity = 8, Cut = 8 }
	end
	local c = cosmetics and table.clone(cosmetics) or {}
	c.Owned = {}
	local folder = Equipment.dressModel(body, kit, 7, c)
	check(folder ~= nil, "the kit didn't dress")
	return body, folder, kit
end
local function parts(root)
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end
local function named(root, name)
	local list = {}
	for _, d in parts(root) do
		if d.Name == name then
			table.insert(list, d)
		end
	end
	return list
end
local function near(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.02
end
-- Whether a point is inside a part (a little inside its surface).
local function inside(part, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2 - Vector3.new(0.02, 0.02, 0.02)
	return math.abs(p.X) < h.X and math.abs(p.Y) < h.Y and math.abs(p.Z) < h.Z
end
local function weldRoot(part)
	local weld = part:FindFirstChildOfClass("WeldConstraint")
	return weld and weld.Part0
end

-- 1. Every gemmed piece shows its stone. ---------------------------------------------------
local body, folder = wear(GEMS)
local STONES = { Helmet = 1, Armor = 1, Gloves = 2, Boots = 2, Shield = 1, Weapon = 1 }
for slot, count in STONES do
	local piece = folder:FindFirstChild(slot)
	check(piece ~= nil, slot .. " wasn't built")
	local gem = { Element = GEMS[slot].Element, Tier = GEMS[slot].Tier }
	local cores = named(piece, "SocketedGem")
	check(#cores == count, string.format("%s shows %d stones, not %d", slot, #cores, count))
	local element = GemConfig.ElementColors[gem.Element]
	check(near(piece:GetAttribute("GemColor"), element), slot .. " doesn't carry its element's colour")
	for _, core in cores do
		check(core.Material == roblox.Enum.Material.Neon, slot .. "'s stone doesn't glow")
		check(near(core.Color, GemConfig.shade(gem).Color), slot .. "'s stone isn't its gem's shade")
		local light = core:FindFirstChild("GemGlow")
		check(light and light:IsA("PointLight") and near(light.Color, element), slot .. "'s stone has no element light")
		check(core:FindFirstChild("GemEffect") ~= nil, slot .. "'s stone has no element effect")
		-- Set on the outside: not buried in the piece's own plates.
		local buried = false
		for _, other in parts(piece) do
			local name = other.Name
			if
				name ~= "SocketedGem"
				and name ~= "GemSetting"
				and name ~= "GemFacet"
				and name ~= "GemIce"
				and name ~= "SkinSeam"
				and other.Transparency < 1
			then
				buried = buried or inside(other, core.CFrame.Position)
			end
		end
		check(not buried, slot .. "'s stone is buried in its armour")
		-- Welded to the body (or the weapon's grip); on the front of it for
		-- armour (the body itself is hidden under the armour, which is
		-- slimmer than it: the armour's own surface is what counts).
		local anchor = weldRoot(core)
		check(
			anchor ~= nil and (anchor.Parent == body or anchor.Name == "RightGrip" or slot == "Shield"),
			slot .. "'s stone isn't held by the body"
		)
		if slot == "Helmet" or slot == "Armor" or slot == "Gloves" or slot == "Boots" then
			local front = anchor.CFrame:PointToObjectSpace(core.CFrame.Position)
			check(-front.Z > 0.25, slot .. "'s stone isn't on the front of the " .. anchor.Name)
			-- Nothing of the piece stands in front of it.
			local ahead = core.CFrame.Position + anchor.CFrame.LookVector * 0.12
			local hidden = false
			for _, other in parts(piece) do
				if other.Transparency < 1 and other.Name == "Gear" then
					hidden = hidden or inside(other, ahead)
				end
			end
			check(not hidden, slot .. "'s stone is covered by its armour")
		end
	end
end
-- Frost shows as ice crystals round its stone.
check(#named(folder:FindFirstChild("Armor"), "GemIce") >= 3, "a Cryo stone has no frost round it")
check(#named(folder:FindFirstChild("Helmet"), "GemIce") == 0, "a Corrosive stone grew ice")
-- A blade carries a touch of its element.
local blade = nil
for _, part in parts(folder:FindFirstChild("Weapon")) do
	if part:FindFirstChild("GemEffect") and part.Name ~= "SocketedGem" then
		blade = part
	end
end
check(blade ~= nil, "an enchanted blade shows nothing of its element")
-- No gem: no stone (the chest and boots stay plain).
local _, plain = wear({ Helmet = GEMS.Helmet })
check(#named(plain:FindFirstChild("Boots"), "SocketedGem") == 0, "an ungemmed piece shows a stone")
check(#named(plain:FindFirstChild("Helmet"), "SocketedGem") == 1, "a lone helmet gem doesn't show")

-- 2. Nothing a preview can't draw. -------------------------------------------------------
local function previewable(root, what)
	for _, d in root:GetDescendants() do
		check(not d:IsA("SelectionBox"), what .. " has a SelectionBox (a preview can't draw it)")
		check(not d:IsA("Highlight"), what .. " has a Highlight (a preview can't draw it)")
	end
end
previewable(folder, "a gemmed kit")
local suits, skins, trimmed = 0, 0, 0
for id, cosmetic in Cosmetics.List do
	if cosmetic.Kind == "Suit" and cosmetic.Palette then
		suits += 1
		local suitBody, suitFolder = wear(GEMS, { Suit = id })
		previewable(suitFolder, id)
		-- 3. Its trim: welded strips on the outward faces of its plates.
		local strips = named(suitFolder, "SkinSeam")
		if cosmetic.Palette.Seams then
			check(#strips >= 30, id .. " has barely any trim (" .. #strips .. " strips)")
			trimmed += 1
		end
		local buried = 0
		for _, strip in strips do
			check(
				strip.Material == roblox.Enum.Material.Neon and strip:HasTag(Tags.SkinSeam),
				id .. " has a dull or untagged trim strip"
			)
			check(typeof(strip:GetAttribute("SeamA")) == "Color3", id .. "'s trim has no seam colour")
			local anchor = weldRoot(strip)
			check(anchor ~= nil and anchor.Parent == suitBody, id .. "'s trim isn't welded to the body")
			-- On a plate's face, not buried in the armour.
			for _, plate in parts(strip.Parent) do
				if plate.Name == "Gear" and plate.Transparency < 1 and inside(plate, strip.CFrame.Position) then
					buried += 1
					break
				end
			end
		end
		check(
			buried <= #strips * 0.1,
			string.format("%s has %d of %d trim strips buried in its armour", id, buried, #strips)
		)
		-- 4. Stones keep their own look under a suit; visors too.
		for _, slot in { "Helmet", "Armor" } do
			local mine = named(suitFolder:FindFirstChild(slot), "SocketedGem")[1]
			local bare = named(folder:FindFirstChild(slot), "SocketedGem")[1]
			check(mine and near(mine.Color, bare.Color), id .. " recoloured the " .. slot .. " stone")
			for _, part in parts(suitFolder:FindFirstChild(slot)) do
				if part.Name == "GemSetting" or part.Name == "GemFacet" then
					check(
						part.Material ~= cosmetic.Palette.PlateMaterial
							or part.Material == roblox.Enum.Material.Metal
							or part.Material == roblox.Enum.Material.Glass,
						id .. " repainted a gem setting"
					)
				end
			end
		end
		-- An element doesn't take over a suit's glowing trims.
		for _, part in parts(suitFolder:FindFirstChild("Gloves")) do
			if part.Material == roblox.Enum.Material.Neon and part.Name == "Gear" then
				check(near(part.Color, cosmetic.Palette.Glow), id .. "'s glove trim took the gem's colour")
			end
		end
	elseif cosmetic.Kind == "Skin" then
		skins += 1
		local _, skinFolder = wear({ Weapon = GEMS.Weapon }, { Skin = id })
		previewable(skinFolder, id)
		local weapon = skinFolder:FindFirstChild("Weapon")
		if cosmetic.Palette and cosmetic.Palette.Edge then
			local edges = 0
			for _, strip in named(weapon, "SkinSeam") do
				edges += if math.max(strip.Size.X, strip.Size.Y, strip.Size.Z) > 1.5 then 1 else 0
			end
			check(edges >= 2, id .. " has no glowing edge down its blade")
		end
		-- 7. First person can hold it.
		check(ViewGrip.frame(weapon, function(part)
			return part.Transparency
		end) ~= nil, "first person can't hold " .. id)
	end
end
check(suits >= 20 and skins >= 25 and trimmed >= 20, "the catalog went missing")
-- A weapon with no straight piece off its grip (just a flat lump out past
-- the fist, nothing standing up from the grip) is still held: along the
-- line from the grip to it.
do
	local weapon = Instance.new("Model")
	local grip = Instance.new("Part")
	grip.Name, grip.Size, grip.CFrame = "RightGrip", Vector3.new(0.05, 0.05, 0.05), CFrame.new(2, 1, 0)
	grip.Parent = weapon
	local lump = Instance.new("Part")
	lump.Size, lump.CFrame = Vector3.new(0.6, 0.4, 1.2), CFrame.new(2, 1, -2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = grip, lump
	weld.Parent = lump
	lump.Parent = weapon
	local frame = ViewGrip.frame(weapon, function(part)
		return part.Transparency
	end)
	check(
		frame ~= nil and (frame.UpVector - Vector3.new(0, 0, -1)).Magnitude < 1e-3,
		"a weapon with no blade isn't held toward its far end"
	)
end

-- 5. The same kit builds the same (the Inventory's miner is the world's).
local function fingerprint(root)
	local list = {}
	for _, part in parts(root) do
		local p = root.Parent:FindFirstChild("HumanoidRootPart").CFrame:PointToObjectSpace(part.CFrame.Position)
		table.insert(
			list,
			string.format(
				"%s|%s|%.2f,%.2f,%.2f|%.2f,%.2f,%.2f|%s",
				part.Name,
				part.Material.Name,
				part.Size.X,
				part.Size.Y,
				part.Size.Z,
				p.X,
				p.Y,
				p.Z,
				part.Color:ToHex()
			)
		)
	end
	table.sort(list)
	return table.concat(list, "\n")
end
local _, once = wear(GEMS, { Suit = "SuitObsidian", Skin = "SkinKindred" })
local _, again = wear(GEMS, { Suit = "SuitObsidian", Skin = "SkinKindred" })
check(fingerprint(once) == fingerprint(again), "the same kit built two different ways")

-- 6. The Armory's previews (one piece at a time) show the piece's stones too.
for slot, count in STONES do
	local rig = FighterRig.build()
	rig:SetAttribute("FistGrip", true)
	local kit = table.clone(KIT)
	kit[slot .. "Gem"] =
		{ Id = slot, Element = GEMS[slot].Element, Tier = GEMS[slot].Tier, Size = 8, Clarity = 8, Cut = 8 }
	local only = Equipment._dress(rig, kit, nil, 7, slot)
	local piece = only and only:FindFirstChild(slot)
	check(piece ~= nil and #named(piece, "SocketedGem") == count, slot .. "'s own preview misses its stone")
	previewable(only, slot .. "'s own preview")
end

-- 7. A stone's light breathes on every client (GemLights), not by a server
-- tween: its pulse is in attributes, the light tagged.
local _, lit = wear(GEMS)
local lights = 0
for _, d in lit:GetDescendants() do
	if d:IsA("PointLight") and d.Name == "GemGlow" then
		lights += 1
		local base, period, dim = d:GetAttribute("PulseBase"), d:GetAttribute("PulsePeriod"), d:GetAttribute("PulseDim")
		check(
			type(base) == "number" and math.abs(base - d.Brightness) < 1e-6,
			"a stone's light doesn't carry its PulseBase"
		)
		check(type(period) == "number" and period > 0, "a stone's light has no PulsePeriod")
		check(type(dim) == "number" and dim > 0 and dim < 1, "a stone's light has no PulseDim")
		check(d:HasTag(Tags.GemGlow), "a stone's light isn't tagged GemGlow")
	end
end
check(lights >= 8, "fewer stone lights than stones")

-- 8. A Prismatic roll under a skin or a suit: the repaint takes the plate's
-- tag, and its PrismaticBase with it (or a copy of it, found by attribute,
-- would shimmer in first person and the previews while the worn gear didn't).
local GearRolls = requireScript(Shared.GearRolls)
local rolled = table.clone(KIT)
rolled.GearRolls = {}
-- (A fixed die: every roll its lowest.)
local die = {
	NextInteger = function(_, low)
		return low
	end,
	NextNumber = function(_, low)
		return low or 0
	end,
}
for slot, kind in { Weapon = "Weapons", Armor = "Armors", Helmet = "Helmets" } do
	local roll = GearRolls.roll(die, 1)
	roll.Prismatic = true
	rolled.GearRolls[kind] = { [KIT[slot]] = roll }
end
local function prismatic(root)
	local tagged, stray = 0, 0
	for _, part in parts(root) do
		if part:GetAttribute("PrismaticBase") ~= nil then
			if part:HasTag(Tags.Prismatic) then
				tagged += 1
			else
				stray += 1
			end
		end
	end
	return tagged, stray
end
local _, plain = wear(nil, nil, rolled)
local shimmering = prismatic(plain)
check(shimmering > 0, "a Prismatic roll shimmered nowhere (the check below would prove nothing)")
for _, cosmetics in
	{
		{ Skin = "SkinNebula" },
		{ Skin = "SkinCrusader" },
		{ Suit = "SuitObsidian" },
		{ Suit = "SuitNeon", Skin = "SkinSolar" },
	}
do
	local _, dressed = wear(nil, cosmetics, rolled)
	local _, stray = prismatic(dressed)
	check(
		stray == 0,
		string.format("%d plates kept PrismaticBase under %s %s", stray, cosmetics.Suit or "", cosmetics.Skin or "")
	)
end

-- 9. Visors (cosmetics, Kind "Visor") on every helmet: the lens takes the
-- look, moving looks are tagged to move, banded lenses run left to right in
-- front of the lens, the legends are framed, the elements come off it, and
-- nothing but the visor changes.
local Cosmetics = requireScript(Shared.Cosmetics)
local visorIds = Cosmetics.ofKind("Visor")
check(#visorIds >= 15, "too few visors")
local function helmetKit(family, rarity)
	local kit = table.clone(KIT)
	kit.Helmet = "Armor" .. family .. "Helmet" .. rarity
	return kit
end
local function signature(root)
	-- Everything that isn't the visor, where it is and how it looks.
	local list = {}
	for _, part in parts(root) do
		if not part:GetAttribute("Visor") then
			local p = root.Parent:FindFirstChild("HumanoidRootPart").CFrame:PointToObjectSpace(part.CFrame.Position)
			table.insert(
				list,
				string.format(
					"%s|%s|%.2f,%.2f,%.2f|%s",
					part.Name,
					part.Material.Name,
					p.X,
					p.Y,
					p.Z,
					part.Color:ToHex()
				)
			)
		end
	end
	table.sort(list)
	return table.concat(list, "\n")
end
local visorLooks, bandsChecked = 0, 0
for _, family in { "Prospector", "Skirmisher", "Juggernaut" } do
	for rarity = 1, 5 do
		local kit = helmetKit(family, rarity)
		local _, bare = wear(nil, nil, kit)
		local plain = signature(bare)
		for _, id in visorIds do
			local look = Cosmetics.get(id).Visor
			local body, folder = wear(nil, { Visor = id }, kit)
			local helmet = folder:FindFirstChild("Helmet")
			local where = family .. rarity .. " " .. id
			visorLooks += 1
			check(signature(folder) == plain, where .. ": the visor changed more than the visor")
			local faces, lenses, rims, lit = {}, {}, 0, 0
			for _, part in parts(helmet) do
				if part.Name == "VisorLens" then
					table.insert(lenses, part)
				elseif part:GetAttribute("VisorFace") and part.Transparency < 1 then
					table.insert(faces, part)
				elseif part.Name == "SkinSeam" and part:GetAttribute("Visor") then
					rims += 1
				end
			end
			check(#faces >= 1, where .. ": no lens to restyle")
			local banded = (look.Bands or 0) > 1
			for _, part in faces do
				if part.Color == look.Color then
					lit += 1
				end
			end
			-- (A banded lens's main piece goes dark behind its bands.)
			check(lit >= #faces - (if banded then 1 else 0), where .. ": a lens piece kept its old colour")
			local material = if look.Material == "Glass" then roblox.Enum.Material.Glass else roblox.Enum.Material.Neon
			for _, part in faces do
				if part.Color == look.Color then
					check(part.Material == material, where .. ": a lens piece has the wrong material")
					check(part:GetAttribute("PrismaticBase") == nil, where .. ": a lens piece would shimmer")
				end
			end
			local moving = {}
			for _, part in faces do
				if part.Color == look.Color then
					table.insert(moving, part)
				end
			end
			for _, part in lenses do
				table.insert(moving, part)
			end
			for _, part in moving do
				if look.Fx then
					check(
						part:GetAttribute("SeamFx") == look.Fx and part:HasTag(Tags.SkinSeam),
						where .. ": a lens piece won't move"
					)
					check(part:GetAttribute("SeamA") == look.Color, where .. ": a lens piece has the wrong colours")
				else
					check(part:GetAttribute("SeamFx") == nil, where .. ": a still lens moves")
				end
			end
			if banded then
				bandsChecked += 1
				check(#lenses == look.Bands, where .. ": " .. #lenses .. " bands, not " .. look.Bands)
				-- Left to right across the face, each a step on from the last.
				local head = body:FindFirstChild("Head")
				table.sort(lenses, function(a, b)
					return head.CFrame:PointToObjectSpace(a.CFrame.Position).X
						< head.CFrame:PointToObjectSpace(b.CFrame.Position).X
				end)
				local seeds = {}
				for _, band in lenses do
					table.insert(seeds, band:GetAttribute("SeamSeed"))
					-- In front of the face, not inside the helmet.
					check(
						head.CFrame:PointToObjectSpace(band.CFrame.Position).Z < -head.Size.Z * 0.3,
						where .. ": a band is inside the helmet"
					)
				end
				local ascending, descending = true, true
				for i = 2, #seeds do
					ascending = ascending and seeds[i] > seeds[i - 1]
					descending = descending and seeds[i] < seeds[i - 1]
				end
				check(ascending or descending, where .. ": the bands aren't seeded across the lens")
			else
				check(#lenses == 0, where .. ": an unbanded lens grew bands")
			end
			check((rims >= 2) == (look.Rim == true), where .. ": the rim is missing or unasked for")
			local effects, glow, pulsing = 0, nil, false
			for _, d in helmet:GetDescendants() do
				if d:IsA("ParticleEmitter") and d.Name == "VisorEffect" then
					effects += 1
				elseif d:IsA("PointLight") and d.Name == "VisorGlow" then
					glow = d
					pulsing = d:GetAttribute("PulseBase") ~= nil and d:HasTag(Tags.GemGlow)
				end
			end
			check((effects > 0) == (look.Element ~= nil), where .. ": its element is missing or unasked for")
			check((glow ~= nil) == (look.Material == "Neon"), where .. ": a lit lens has no light, or glass has one")
			check(
				pulsing == (look.Fx == "Pulse" or look.Fx == "Flicker"),
				where .. ": its light doesn't breathe with it"
			)
		end
	end
end
-- Under a suit the visor still shows (a suit dresses the armour, not the face).
local _, suited = wear(nil, { Suit = "SuitObsidian", Visor = "VisorAurora" }, helmetKit("Juggernaut", 3))
check(#named(suited.Helmet, "VisorLens") == Cosmetics.get("VisorAurora").Visor.Bands, "a suit took the visor off")
-- The Armory's one-helmet preview wears it too.
do
	local rig = FighterRig.build()
	rig:SetAttribute("FistGrip", true)
	local only = Equipment._dress(rig, helmetKit("Prospector", 2), { Visor = "VisorScanner" }, 7, "Helmet")
	check(only and #named(only.Helmet, "VisorLens") == 9, "the one-helmet preview has no visor")
end

-- 10. Helmet skins (cosmetics, Kind "Helmet"): the helmet's own model gives
-- way to the skin, the avatar's head is hidden under it (and shows again once
-- it's off), its gem is set on the skin's seat, a suit, a gem and the rarity
-- shine leave it in its own colours, every visor lights its eyes (a dark glass
-- one too), and the one-helmet preview wears it.
local helmetIds = Cosmetics.ofKind("Helmet")
check(#helmetIds >= 12, "too few helmet skins")
local function weldedTo(part)
	local weld = part:FindFirstChildOfClass("WeldConstraint")
	return weld and weld.Part0
end
local helmetsWorn = 0
local bareHead = wear(GEMS, nil):FindFirstChild("Head")
for _, id in helmetIds do
	local look = Cosmetics.get(id)
	local body, folder = wear(GEMS, { Helmet = id, Suit = "SuitObsidian" })
	local helmet = folder:FindFirstChild("Helmet")
	check(helmet and helmet:GetAttribute("HelmetSkin") == look.Look, id .. ": the skin wasn't built")
	helmet = helmet or folder
	helmetsWorn += 1
	local skinParts, eyes, seated = 0, 0, false
	for _, part in parts(helmet) do
		if part:GetAttribute("VisorFace") then
			check(part:GetAttribute("VisorFit") ~= nil, id .. ": the standard helmet's lens is still there")
		end
		if part.Name == "HelmSkin" then
			skinParts += 1
			local color = part:GetAttribute("SkinColor")
			if typeof(color) == "Color3" then
				check(near(part.Color, color), id .. ": a part lost its own colour to the suit, gem or shine")
			end
			if part:GetAttribute("VisorFit") == "Eye" then
				eyes += 1
			end
		end
		local seat = weldedTo(part)
		if part.Name == "SocketedGem" and seat and seat:GetAttribute("StoneSeat") then
			-- Set on the front of its seat, facing out.
			local head = body:FindFirstChild("Head")
			local out = (part.CFrame.Position - seat.CFrame.Position):Dot(head.CFrame.LookVector)
			check(out > 0, id .. ": its gem is set behind its seat")
			seated = true
		end
	end
	check(skinParts >= 10, id .. ": too little of the skin was built")
	check(#named(helmet, "SkinSeam") == 0, id .. ": the suit drew its seams on the skin")
	check(eyes >= 1, id .. " has no eyes to light")
	check(seated, id .. ": its gem isn't set on the skin's seat")
	local head = body:FindFirstChild("Head")
	check(head.Transparency == 1, id .. ": the avatar's head shows through the skin")
	-- Off again: the head and its face as the kit leaves them without one
	-- (today's armour hides the whole avatar anyway).
	Equipment.dressModel(body, table.clone(KIT), 7, { Owned = {} })
	check(head:GetAttribute("SkinHid") == nil, id .. ": the head was never given back once the skin was off")
	check(head.Transparency == bareHead.Transparency, id .. ": the head isn't as the kit leaves it, once the skin is off")
	for _, decal in head:GetChildren() do
		if decal:IsA("Decal") then
			check(decal:GetAttribute("SkinHid") == nil, id .. ": the face was never given back once the skin was off")
		end
	end
	-- Every visor lights its eyes, a dark glass one too.
	for _, visorId in { "VisorLime", "VisorSmoke", "VisorSupernova" } do
		local lens = Cosmetics.get(visorId).Visor
		local _, lit = wear(nil, { Helmet = id, Visor = visorId })
		for _, part in parts(lit:FindFirstChild("Helmet") or lit) do
			local fit = part:GetAttribute("VisorFit")
			if fit == "Eye" or part:GetAttribute("VisorTint") then
				local _, _, v = part.Color:ToHSV()
				check(part.Material == roblox.Enum.Material.Neon and v >= 0.85, id .. " + " .. visorId .. ": an eye isn't lit")
				if lens.Material == "Neon" then
					check(near(part.Color, lens.Color), id .. " + " .. visorId .. ": an eye isn't the visor's colour")
				end
				check((part:GetAttribute("SeamFx") ~= nil) == (lens.Fx ~= nil or part:GetAttribute("SeamFx") ~= nil), id .. ": an eye's movement is lost")
			elseif fit == "Lens" then
				check(part.Material == roblox.Enum.Material.Glass, id .. " + " .. visorId .. ": a lens isn't glass")
			end
		end
		check(#named(lit, "VisorLens") == 0, id .. " + " .. visorId .. ": a skin's eyes were cut into bands")
	end
end
-- With a look that doesn't hide the avatar (today's armour all does), a skin
-- still hides the head under it, and gives it back, face and all.
do
	local Classes = requireScript(Shared.Classes)
	local defs = {
		Classes.gear(KIT.Class, "Helmets", KIT.Helmet),
		Classes.armor(KIT.Class, KIT.Armor),
		Classes.gear(KIT.Class, "Gloves", KIT.Gloves),
		Classes.gear(KIT.Class, "Boots", KIT.Boots),
	}
	local looks = {}
	for i, def in defs do
		looks[i] = def.Look
		def.Look = "Bulwark"
	end
	local body = wear(nil, nil)
	local head = body:FindFirstChild("Head")
	check(head.Transparency == 0, "(that plain look hides the avatar: pick another for this check)")
	Equipment.dressModel(body, table.clone(KIT), 7, { Owned = {}, Helmet = helmetIds[1] })
	check(head.Transparency == 1, "a helmet skin left the avatar's head showing through it")
	Equipment.dressModel(body, table.clone(KIT), 7, { Owned = {} })
	check(head.Transparency == 0, "the head stayed hidden once the skin was off")
	local faces = 0
	for _, decal in head:GetChildren() do
		if decal:IsA("Decal") then
			faces += 1
			check(decal.Transparency == 0, "the face stayed hidden once the skin was off")
		end
	end
	check(faces > 0, "(the rig has no face to check)")
	for i, def in defs do
		def.Look = looks[i]
	end
end
do
	local rig = FighterRig.build()
	local only = Equipment._dress(rig, table.clone(KIT), { Owned = {}, Helmet = helmetIds[1] }, 7, "Helmet")
	check(only and only.Helmet and only.Helmet:GetAttribute("HelmetSkin") ~= nil, "the one-helmet preview has no skin")
end
-- The Store's preview of each skin is the skin as worn, rounded parts and
-- all: every egg and tube keeps its mesh (stripped, each showed as a box).
services.Players.CreateHumanoidModelFromDescription = function()
	return FighterRig.build()
end
local function rounded(root)
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and d:FindFirstChildOfClass("SpecialMesh") then
			n += 1
		end
	end
	return n
end
for _, id in helmetIds do
	check(Equipment.cosmeticPreview(id), id .. ": no store preview")
	local store = game:GetService("ReplicatedStorage"):FindFirstChild("CosmeticPreviews")
	local preview = store and store:FindFirstChild(id)
	local _, folder = wear(nil, { Helmet = id })
	local worn = rounded(folder:FindFirstChild("Helmet"))
	local shown = if preview then rounded(preview) else 0
	check(
		worn > 0 and shown == worn,
		string.format("%s: the store preview has %d of its %d rounded parts", id, shown, worn)
	)
end

print(
	string.format(
		"PASS: %d gear look checks (stones on every gemmed piece, %d suits trimmed in real parts, %d skins held in first person, %d visor looks on 15 helmets, %d banded, %d helmet skins worn, nothing a preview can't draw)",
		checks,
		trimmed,
		skins,
		visorLooks,
		bandsChecked,
		helmetsWorn
	)
)
