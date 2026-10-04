-- Exports posed, armoured fighters for tools/make_lobby_cards.py.
--   lune run tools/card_poses.luau <out.json> 0 player <Weapon> [stance]
-- An R15 body in Frontier armor with a weapon (Sword, or a Forge weapon) and
-- a shield, posed by the game's own RivalPose.update, then the joints solved
-- forward to place every part. "stance" bends the legs into a planted lunge.
-- Run from the repo root (or set GEMSOUL_ROOT).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Instance, CFrame, Vector3, Color3 = roblox.Instance, roblox.CFrame, roblox.Vector3, roblox.Color3
local ROOT = process.env.GEMSOUL_ROOT or "."
local OUT = process.args[1]
local REST = process.args[2] == "1"
local FIST = process.args[3] == "fist"
local WEAPON = process.args[4] or "Cleaver"

local cache = {}
local load
local shared = setmetatable({}, { __index = function(_, k) return k end })
local function req(m)
	if type(m) ~= "string" then return m end
	if not cache[m] then cache[m] = load(ROOT .. "/src/shared/" .. m .. ".luau") end
	return cache[m]
end
local clockNow = 0
function load(path)
	local env = setmetatable({ Instance = Instance, CFrame = CFrame, Vector3 = Vector3, Color3 = Color3, Enum = roblox.Enum,
		NumberSequence = roblox.NumberSequence, ColorSequence = roblox.ColorSequence, UDim2 = roblox.UDim2, task = require("@lune/task"),
		NumberRange = roblox.NumberRange, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		typeof = roblox.typeof or typeof,
		game = { GetService = function() return { Shared = shared } end },
		script = { Parent = shared }, require = function(m) return req(m) end }, { __index = _G })
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end
local ArmorKits = load(ROOT .. "/src/server/Systems/ArmorKits.luau")
local Assets = load(ROOT .. "/src/server/Systems/FrontierAssets.luau")
local RivalPose = req("RivalPose")

-- Classic blocky R15: name, centre, size.
local PARTS = {
	{ "LowerTorso", 0, 0, 2, 0.4, 1 }, { "UpperTorso", 0, 1, 2, 1.6, 1 }, { "Head", 0, 2.4, 1.2, 1.2, 1.2 },
	{ "RightUpperArm", 1.5, 1.1, 1, 1.2, 1 }, { "RightLowerArm", 1.5, 0.05, 1, 1.0, 1 }, { "RightHand", 1.5, -0.6, 1, 0.3, 1 },
	{ "LeftUpperArm", -1.5, 1.1, 1, 1.2, 1 }, { "LeftLowerArm", -1.5, 0.05, 1, 1.0, 1 }, { "LeftHand", -1.5, -0.6, 1, 0.3, 1 },
	{ "RightUpperLeg", 0.5, -0.9, 1, 1.2, 1 }, { "RightLowerLeg", 0.5, -2, 1, 1.0, 1 }, { "RightFoot", 0.5, -2.65, 1, 0.3, 1 },
	{ "LeftUpperLeg", -0.5, -0.9, 1, 1.2, 1 }, { "LeftLowerLeg", -0.5, -2, 1, 1.0, 1 }, { "LeftFoot", -0.5, -2.65, 1, 0.3, 1 },
}
-- Joint name, Part0, Part1, world position of the joint.
local JOINTS = {
	{ "Waist", "LowerTorso", "UpperTorso", 0, 0.2 }, { "Neck", "UpperTorso", "Head", 0, 1.8 },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", 1.5, 1.6 }, { "RightElbow", "RightUpperArm", "RightLowerArm", 1.5, 0.55 },
	{ "RightWrist", "RightLowerArm", "RightHand", 1.5, -0.45 },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", -1.5, 1.6 }, { "LeftElbow", "LeftUpperArm", "LeftLowerArm", -1.5, 0.55 },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", -1.5, -0.45 },
	{ "RightHip", "LowerTorso", "RightUpperLeg", 0.5, -0.25 }, { "RightKnee", "RightUpperLeg", "RightLowerLeg", 0.5, -1.5 },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", 0.5, -2.5 },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", -0.5, -0.25 }, { "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", -0.5, -1.5 },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", -0.5, -2.5 },
}

local function buildBody()
	local body = Instance.new("Model")
	local h = Instance.new("Humanoid"); h.Health = 100; h.Parent = body
	local parts = {}
	for _, r in PARTS do
		local part = Instance.new("Part")
		part.Name = r[1]
		part.Size = Vector3.new(r[4], r[5], r[6])
		part.CFrame = CFrame.new(r[2], r[3], 0)
		part.Color = Color3.fromRGB(214, 170, 130)
		part.Parent = body
		parts[r[1]] = part
	end
	local motors = {}
	for _, j in JOINTS do
		local p0, p1 = parts[j[2]], parts[j[3]]
		local at = CFrame.new(j[4], j[5], 0)
		local m = Instance.new("Motor6D")
		m.Name = j[1]
		m.Part0, m.Part1 = p0, p1
		m.C0 = p0.CFrame:ToObjectSpace(at)
		m.C1 = p1.CFrame:ToObjectSpace(at)
		m.Parent = p1
		table.insert(motors, m)
	end
	if FIST then body:SetAttribute("FistGrip", true) end
	body.Parent = Instance.new("Folder")
	return body, parts, motors
end

local body, parts, motors = buildBody()
local accent, finish = Color3.fromRGB(80, 210, 255), Color3.fromRGB(70, 110, 160)
local folder = Instance.new("Folder"); folder.Parent = body
ArmorKits.build(folder, body, "HeavyVanguard", accent, 3)
-- The weapon in the right hand, the shield on the left forearm, as Equipment mounts them.
local function anchorAt(part, offset, name)
	local a = Instance.new("Part"); a.Name = name; a.Size = Vector3.one * 0.05; a.Transparency = 1
	a.CFrame = part.CFrame * offset
	local w = Instance.new("WeldConstraint"); w.Part0, w.Part1, w.Parent = part, a, a
	a.Parent = folder
	return a
end
local UPRIGHT = CFrame.Angles(math.rad(-12), 0, 0)
local mount = if FIST then CFrame.Angles(math.rad(-120), 0, 0) else UPRIGHT * CFrame.Angles(0, 0, math.rad(-12))
local right = anchorAt(parts.RightHand, CFrame.new(0, -0.1, 0), "RightGrip")
local before = {}
for _, d in folder:GetDescendants() do d:SetAttribute("Pre", true) end
if WEAPON == "Sword" then
	Assets.sword(folder, right, mount, 4, accent, finish)
else
	Assets.forge(WEAPON, folder, right, mount, 4, accent, finish)
end
for _, d in folder:GetDescendants() do
	if not d:GetAttribute("Pre") and d:IsA("BasePart") then d:SetAttribute("Weapon", true) end
end
if WEAPON == "TwinBlades" then
	local left = anchorAt(parts.LeftHand, CFrame.new(0, -0.1, 0), "LeftGrip")
	local off = if FIST then CFrame.Angles(math.rad(-120), 0, 0) else UPRIGHT * CFrame.Angles(0, 0, math.rad(12))
	Assets.forge("TwinBlades", folder, left, off, 4, accent, finish)
else
	local arm = parts.LeftLowerArm
	local turn = if FIST then 110 else 90
	local smount = CFrame.new(-(arm.Size.X / 2 + 0.2), 0, 0) * CFrame.Angles(0, math.rad(turn), 0)
	Assets.shield(folder, arm, smount, 4, accent, finish, "Juggernaut")
end
-- Every part gets an id (instance handles aren't stable table keys here).
local byId, nextId = {}, 0
local function idOf(p)
	local id = p:GetAttribute("Uid")
	if not id then
		nextId += 1
		id = nextId
		p:SetAttribute("Uid", id)
		byId[id] = p
	end
	return id
end
for _, d in body:GetDescendants() do
	if d:IsA("BasePart") then idOf(d) end
end
-- Every gear part's offset from what it's welded to, at bind time.
local bound = {}
for _, d in folder:GetDescendants() do
	if d:IsA("BasePart") then
		local w = d:FindFirstChildOfClass("WeldConstraint")
		if w and w.Part0 then
			bound[idOf(d)] = { To = idOf(w.Part0), Offset = w.Part0.CFrame:ToObjectSpace(d.CFrame) }
		end
	end
end
local joints = {}
for _, m in motors do
	table.insert(joints, { M = m, P0 = idOf(m.Part0), P1 = idOf(m.Part1) })
end
local function solve()
	-- Forward kinematics from the lower torso.
	local placed = { [idOf(parts.LowerTorso)] = true }
	local changed = true
	while changed do
		changed = false
		for _, j in joints do
			if placed[j.P0] and not placed[j.P1] then
				byId[j.P1].CFrame = byId[j.P0].CFrame * j.M.C0 * j.M.C1:Inverse()
				placed[j.P1] = true
				changed = true
			end
		end
	end
	local done = {}
	local function place(id)
		if done[id] or not bound[id] then return end
		place(bound[id].To)
		byId[id].CFrame = byId[bound[id].To].CFrame * bound[id].Offset
		done[id] = true
	end
	for id in bound do place(id) end
end

local function export(label)
	solve()
	local list = {}
	for _, d in body:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local cf = d.CFrame
			local shape = if d.ClassName == "WedgePart" then "Wedge" else d.Shape.Name
			table.insert(list, { cf.X, cf.Y, cf.Z, cf.RightVector.X, cf.RightVector.Y, cf.RightVector.Z, cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z,
				cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z, d.Size.X, d.Size.Y, d.Size.Z, d.Color.R, d.Color.G, d.Color.B, shape,
				d.Material == roblox.Enum.Material.Neon, d:GetAttribute("Weapon") == true })
		end
	end
	local grip = folder:FindFirstChild("RightGrip")
	return { Name = label, Parts = list, Grip = if grip then { grip.CFrame.X, grip.CFrame.Y, grip.CFrame.Z } else nil }
end

-- Each animation: its attributes and the moments to show.
local ANIMS = {
	{ "Slash", { ActionKind = "Slash", ActionStart = 100, ActionAt = 100.3, ActionSide = 1 }, { { 100.27, "wind-up" }, { 100.34, "strike" }, { 100.55, "follow-through" } } },
	{ "Slash (other side)", { ActionKind = "Slash", ActionStart = 100, ActionAt = 100.3, ActionSide = -1 }, { { 100.27, "wind-up" }, { 100.34, "strike" }, { 100.55, "follow-through" } } },
	{ "Heavy", { ActionKind = "Heavy", ActionStart = 100, ActionAt = 100.75 }, { { 100.7, "wind-up" }, { 100.8, "slam" }, { 101.0, "follow-through" } } },
	{ "Charging a heavy", { ActionKind = "Slash", ActionStart = 100, ActionAt = 103, ActionSide = 1 }, { { 100.3, "drawing back" }, { 101.5, "held" }, { 102.9, "fully drawn" } } },
	{ "Bolt cast", { ActionKind = "Bolt", ActionStart = 100, ActionAt = 100.45 }, { { 100.4, "gathering" }, { 100.5, "release" }, { 100.8, "after" } } },
	{ "Beam (held)", { ActionKind = "Bolt", ActionStart = 100, ActionAt = 100.4, ActionHold = 102 }, { { 100.35, "gathering" }, { 101.0, "pouring" }, { 101.9, "pouring" } } },
	{ "Ground blast", { ActionKind = "Nova", ActionStart = 100, ActionAt = 100.9 }, { { 100.8, "arms up" }, { 100.95, "slam down" }, { 101.25, "after" } } },
	{ "Buff", { ActionKind = "Buff", ActionStart = 100, ActionAt = 100.15 }, { { 100.12, "gathering" }, { 100.4, "arms wide" }, { 100.8, "after" } } },
	{ "Dodge roll", { ActionKind = "Dodge", ActionStart = 100, ActionAt = 100, ActionSide = 1 }, { { 100.06, "start" }, { 100.2, "tucked" }, { 100.5, "recovering" } } },
	{ "Stagger", { ActionKind = "Stagger", ActionStart = 100, ActionAt = 100 }, { { 100.06, "hit" }, { 100.25, "rocked" }, { 100.6, "recovering" } } },
	{ "Guard (blocking)", { GuardUntil = 110 }, { { 100.3, "raising" }, { 101, "held" }, { 101.5, "held" } } },
	{ "Block jolt", { GuardUntil = 110, BlockedAt = 101 }, { { 100.9, "guard" }, { 101.06, "blow lands" }, { 101.2, "settling" } } },
	{ "Flinch (hit)", { HurtAt = 100.5, HurtSide = 1 }, { { 100.45, "before" }, { 100.56, "flinch" }, { 100.75, "fading" } } },
	{ "Stance", {}, { { 100.0, "breathing" }, { 100.6, "breathing" }, { 101.3, "breathing" } } },
}

local out = {}
for _, anim in ANIMS do
	for _, frame in anim[3] do
		-- Fresh rig state each frame: settle from rest up to the moment, 60 fps.
		for _, m in motors do
			local rest = m:GetAttribute("RestPose")
			if rest then m.C0 = rest end
		end
		local model = body
		for _, k in { "ActionKind", "ActionStart", "ActionAt", "ActionSide", "ActionHold", "GuardUntil", "HurtAt", "HurtSide", "BlockedAt" } do
			model:SetAttribute(k, anim[2][k])
		end
		-- A fresh copy of the pose code each frame: no smoothing state carried over.
		RivalPose = load(ROOT .. "/src/shared/RivalPose.luau")
		local t = 99.0
		RivalPose.update(model, 1 / 60, t, 0, REST)
		while t < frame[1] do
			t += 1 / 60
			RivalPose.update(model, 1 / 60, t, 1, REST)
		end
		if process.args[5] == "stance" then
			-- A fighting stance for key art: shield-side foot forward, knees bent.
			local LEGS = { LeftHip = { 34, 6 }, LeftKnee = { -38, 0 }, LeftAnkle = { 4, 0 }, RightHip = { -26, -6 }, RightKnee = { -6, 0 }, RightAnkle = { 32, 0 } }
			for _, m in motors do
				local spec = LEGS[m.Name]
				if spec then
					m.C0 = m.C0 * CFrame.Angles(math.rad(spec[1]), 0, math.rad(spec[2]))
				end
			end
		end
		local entry = export(anim[1] .. " · " .. frame[2])
		entry.Anim, entry.Frame = anim[1], frame[2]
		table.insert(out, entry)
	end
end
fs.writeFile(OUT, serde.encode("json", out))
print("frames", #out)
