-- lune run tests/fallen_miner_cases.luau <repo> [dump.json]
-- The fallen miners in the dungeons and the Rift are real miners: the
-- fighter rig every player wears, dressed by the real Equipment in a kit
-- rolled at random (Server.Systems.FallenCrew), laid down by
-- Server.World.FallenMiners in its death poses:
--   * every roll is a whole kit of real catalogue gear, and the rolls differ
--     (helmets, chests, weapons), some with a gem or two;
--   * some wear a suit, a weapon skin, a visor or a helmet skin, some wear
--     nothing for looks, and the looks are real cosmetics of the right kind;
--   * laid down, a miner is a prop: no Humanoid, every part anchored,
--     nothing to bump into or press, lying low (its head near the floor,
--     never standing), its gear still on it (each welded piece where it
--     sat on its limb), its pose recorded;
--   * the old suit still stands in when no body is handed over (the world
--     tests build without one).
-- With a second argument the laid-out line-up is dumped as parts for an
-- offline render.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local Instance, CFrame, Vector3, Color3 = roblox.Instance, roblox.CFrame, roblox.Vector3, roblox.Color3
local ROOT = process.args[1] or "."


-- A seeded Random (lune has none): Park-Miller, the one the modules get too.
local Random = {
	new = function(seed)
		local state = (seed or 7) % 2147483647
		if state <= 0 then
			state += 2147483646
		end
		-- (Warmed up: a small seed's first draws are all tiny.)
		for _ = 1, 5 do
			state = (state * 16807) % 2147483647
		end
		local r = {}
		function r:NextNumber(a, b)
			state = (state * 16807) % 2147483647
			local x = state / 2147483647
			return if a then a + (b - a) * x else x
		end
		function r:NextInteger(a, b)
			state = (state * 16807) % 2147483647
			return a + math.floor(state / 2147483647 * (b - a + 1))
		end
		return r
	end,
}
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
		Random = Random,
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

local serde = require("@lune/serde")
local Equipment = requireScript(systems.Equipment)
local FighterRig = requireScript(systems.FighterRig)
local FallenCrew = requireScript(systems.FallenCrew)
local FallenMiners = requireScript(game:GetService("ServerScriptService").Server.World.FallenMiners)
local Shared = game:GetService("ReplicatedStorage").Shared
local Classes = requireScript(Shared.Classes)
local Cosmetics = requireScript(Shared.Cosmetics)
local Slots = requireScript(Shared.EquipmentSlots)

-- The rolls: whole kits of real gear, no two alike, some gems, some looks.
local armors, helmets, weapons = {}, {}, {}
local suits, skins, visors, helmetSkins, bare, gemmed = 0, 0, 0, 0, 0, 0
local N = 40
for i = 1, N do
	local loadout, cosmetics = FallenCrew.roll(Random.new(100 + i))
	for _, slot in Slots.Order do
		local kind = Slots.Definitions[slot].Kind
		check(loadout[slot] ~= nil, "Roll " .. i .. " has no " .. slot)
		check(Classes.gear("Warrior", kind, loadout[slot]) ~= nil, "Roll " .. i .. "'s " .. slot .. " isn't real gear: " .. tostring(loadout[slot]))
		check(loadout.GearRolls[kind] and loadout.GearRolls[kind][loadout[slot]] ~= nil, "Roll " .. i .. "'s " .. slot .. " has no roll")
		if loadout[slot .. "Gem"] then
			gemmed += 1
		end
	end
	local weapon = Classes.weapon("Warrior", loadout.Weapon)
	check(weapon and weapon.WeaponType ~= "Pistol", "Roll " .. i .. " carries a pistol")
	-- Swords only, and armor of the families players wear today.
	check(weapon and weapon.WeaponType == "Sword", "Roll " .. i .. " carries a " .. tostring(weapon and weapon.WeaponType) .. ", not a sword")
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots", "Shield" } do
		local piece = Classes.gear("Warrior", Slots.Definitions[slot].Kind, loadout[slot])
		check(piece and piece.ArmorFamily ~= nil, "Roll " .. i .. "'s " .. slot .. " (" .. tostring(loadout[slot]) .. ") isn't a family piece")
	end
	armors[loadout.Armor], helmets[loadout.Helmet], weapons[loadout.Weapon] = true, true, true
	local any = false
	for _, kind in { "Suit", "Skin", "Visor", "Helmet" } do
		local id = cosmetics[kind]
		if id then
			any = true
			local c = Cosmetics.get(id)
			check(c ~= nil and c.Kind == kind, "Roll " .. i .. "'s " .. kind .. " isn't a " .. kind .. ": " .. tostring(id))
			check(cosmetics.Owned[id] == true, "Roll " .. i .. " doesn't own its " .. kind)
		end
	end
	if cosmetics.Suit then suits += 1 end
	if cosmetics.Skin then skins += 1 end
	if cosmetics.Visor then visors += 1 end
	if cosmetics.Helmet then helmetSkins += 1 end
	if not any then bare += 1 end
end
local function count(set)
	local n = 0
	for _ in set do
		n += 1
	end
	return n
end
check(count(armors) >= 5, "Only " .. count(armors) .. " chests across " .. N .. " rolls")
check(count(helmets) >= 5, "Only " .. count(helmets) .. " helmets across " .. N .. " rolls")
check(count(weapons) >= 3, "Only " .. count(weapons) .. " weapons across " .. N .. " rolls")
check(suits >= 6 and suits <= N - 6, suits .. " of " .. N .. " wear a suit")
check(skins >= 4, skins .. " of " .. N .. " wear a weapon skin")
check(visors >= 5, visors .. " of " .. N .. " wear a visor")
check(helmetSkins >= 3, helmetSkins .. " of " .. N .. " wear a helmet skin")
check(bare >= 2, "Only " .. bare .. " of " .. N .. " wear nothing for looks")
check(gemmed >= 10, "Only " .. gemmed .. " gems across " .. N .. " rolls")

-- Laid down: a prop, lying low, its gear still on it.
FallenCrew.start()
check(FallenMiners.dresser ~= nil, "FallenCrew hands FallenMiners no bodies")
local holder = Instance.new("Folder")
holder.Parent = game:GetService("Workspace")
local floorY = 0
local BODY = { "Head", "UpperTorso", "LowerTorso", "RightHand", "LeftHand", "RightFoot", "LeftFoot" }
local lineup = {}
local partCounts = {}
for i, pose in { "Curled", "FaceDown", "Sprawled", "Curled", "FaceDown", "Sprawled" } do
	local at = Vector3.new((i - 3.5) * 8, floorY, 0)
	local model = FallenMiners.place(holder, at, Vector3.new(0, 0, -1), Random.new(300 + i), { Pose = pose, Glow = Color3.fromRGB(255, 120, 60), Shards = i % 2 == 0 })
	table.insert(lineup, model)
	check(model:GetAttribute("Pose") == pose, "Pose not recorded")
	check(model:GetAttribute("Dressed") == true, "The miner wasn't dressed")
	check(model:FindFirstChildWhichIsA("Humanoid", true) == nil, "A fallen miner with a Humanoid")
	check(model:FindFirstChildWhichIsA("Motor6D", true) == nil, "A fallen miner still jointed")
	local gear = model:FindFirstChild("GemsoulGear")
	check(gear ~= nil, "No gear on the fallen miner")
	local gearParts, total = 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			total += 1
			check(d.Anchored, d.Name .. " isn't anchored")
			check(not d.CanCollide and not d.CanQuery and not d.CanTouch, d.Name .. " is something to bump into")
			if d:IsDescendantOf(gear) then
				gearParts += 1
			end
		end
	end
	partCounts[i] = total
	check(gearParts >= 20, "Only " .. gearParts .. " gear parts on the fallen miner")
	for _, name in BODY do
		local part = model:FindFirstChild(name)
		check(part ~= nil, "The fallen miner has no " .. name)
		check(part.CFrame.Position.Y - floorY < 3.4, name .. " is " .. string.format("%.1f", part.CFrame.Position.Y - floorY) .. " up: not lying down (" .. pose .. ")")
		check(part.CFrame.Position.Y - floorY > -0.6, name .. " is under the floor (" .. pose .. ")")
		check((part.CFrame.Position - at).Magnitude < 7, name .. " lies far from where it was placed")
	end
	local head = model:FindFirstChild("Head")
	check(head.CFrame.Position.Y - floorY < 2, pose .. ": the head's up in the air (" .. string.format("%.2f", head.CFrame.Position.Y - floorY) .. ")")
	-- Its sword lies flat on the floor by its hand, out of its grip.
	local weapon = model:FindFirstChild("GemsoulGear") and model.GemsoulGear:FindFirstChild("Weapon")
	check(weapon ~= nil and model:GetAttribute("WeaponDown") == true, pose .. ": no sword dropped")
	if weapon then
		local hand = model:FindFirstChild("RightHand")
		local lowest, highest, nearest = math.huge, -math.huge, math.huge
		local blades = 0
		for _, d in weapon:GetDescendants() do
			if d:IsA("BasePart") then
				blades += 1
				local half = d.Size / 2
				for sx = -1, 1, 2 do
					for sy = -1, 1, 2 do
						for sz = -1, 1, 2 do
							local corner = d.CFrame * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)
							lowest = math.min(lowest, corner.Y)
							highest = math.max(highest, corner.Y)
						end
					end
				end
				nearest = math.min(nearest, (d.CFrame.Position - hand.CFrame.Position).Magnitude)
			elseif d:IsA("WeldConstraint") then
				check(false, pose .. ": the sword's still welded to the hand")
			end
		end
		check(blades >= 3, pose .. ": the sword has only " .. blades .. " parts")
		check(highest - floorY < 1.0, pose .. ": the sword's " .. string.format("%.2f", highest - floorY) .. " up, not on the floor")
		check(lowest - floorY > -0.05, pose .. ": the sword's through the floor (" .. string.format("%.2f", lowest - floorY) .. ")")
		check(nearest < 3.5, pose .. ": the sword lies " .. string.format("%.1f", nearest) .. " studs from the hand")
	end
	-- Each welded piece still sits on its limb where it sat.
	for _, d in model:GetDescendants() do
		if d:IsA("WeldConstraint") and d.Part0 and d.Part1 then
			check((d.Part0.CFrame.Position - d.Part1.CFrame.Position).Magnitude < 4.5, d.Part1.Name .. " came off " .. d.Part0.Name)
		end
	end
	check(model:FindFirstChild("Stain") ~= nil, "No stain under the fallen miner")
end
-- In a live place the rig is one welded assembly until it's anchored, and
-- moving one unanchored part moves the lot: the body is anchored before
-- any part of it is placed (lune has no assemblies, so this reads the code).
do
	local source = fs.readFile(ROOT .. "/src/server/World/FallenMiners.luau")
	local layAt = string.find(source, "local function lay(", 1, true)
	local anchorAt = string.find(source, "d.Anchored = true", layAt, true)
	local poseAt = string.find(source, "root.CFrame = rootFrame", layAt, true)
	check(layAt and anchorAt and poseAt and anchorAt < poseAt, "The body isn't anchored before it's posed")
	local crew = fs.readFile(ROOT .. "/src/server/Systems/FallenCrew.luau")
	check(string.find(crew, "part.Anchored = true", 1, true) ~= nil, "The rig isn't anchored when it's built")
end
-- (and the old suit when there's no body to be had)
FallenMiners.dresser = nil
local old = FallenMiners.place(holder, Vector3.new(0, 0, 40), Vector3.new(0, 0, -1), Random.new(9), { Pose = "Curled" })
check(old:GetAttribute("Dressed") == nil and old:FindFirstChild("Helmet") ~= nil, "No old suit without a dresser")
local most = 0
for _, n in partCounts do
	most = math.max(most, n)
end
print(string.format("PASS: %d fallen miner checks (%d rolls: %d chests, %d helmets, %d weapons; %d suits, %d skins, %d visors, %d helmet skins, %d bare; up to %d parts laid out)", checks, N, count(armors), count(helmets), count(weapons), suits, skins, visors, helmetSkins, bare, most))

-- A dump for the offline render: the line-up's parts and lights.
local out = process.args[2]
if out then
	local parts, lights = {}, {}
	for _, model in lineup do
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.98 then
				local cf = d.CFrame
				local p = cf.Position
				local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
				local shape = "Block"
				if d.ClassName == "WedgePart" or d.ClassName == "CornerWedgePart" then
					shape = "Wedge"
				elseif d.ClassName == "Part" and d.Shape == roblox.Enum.PartType.Ball then
					shape = "Ball"
				elseif d.ClassName == "Part" and d.Shape == roblox.Enum.PartType.Cylinder then
					shape = "Cylinder"
				end
				local mesh = d:FindFirstChildOfClass("SpecialMesh")
				if mesh and mesh.MeshType == roblox.Enum.MeshType.Sphere then
					shape = "Ellipsoid"
				end
				table.insert(parts, {
					p.X, p.Y, p.Z, r.X, r.Y, r.Z, u.X, u.Y, u.Z, l.X, l.Y, l.Z,
					d.Size.X, d.Size.Y, d.Size.Z, d.Color.R, d.Color.G, d.Color.B,
					shape, d.Material == roblox.Enum.Material.Neon, 0, d.Material.Name, d.Transparency,
				})
				local pl = d:FindFirstChildOfClass("PointLight")
				if pl then
					table.insert(lights, { p.X, p.Y, p.Z, pl.Color.R, pl.Color.G, pl.Color.B, pl.Range, pl.Brightness })
				end
			end
		end
	end
	fs.writeFile(out, serde.encode("json", { parts = parts, lights = lights }))
	print("dumped", #parts, "parts", #lights, "lights to", out)
end
