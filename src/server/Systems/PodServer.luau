--[[
	Personal pods (Shared.Pods): a pod for everyone in the server, on one of
	the settlement's pads (Server.World.OutpostWorld builds them), next to a
	friend's if a friend is here. It lands from orbit when you join and lifts
	off when you leave.

	Where you start in the Outpost, and come back to (a respawn, a duel, the
	Rift), is the foot of its ramp: the player's PodSpawn attribute (a
	CFrame), read by OutpostServer, ArenaSessions, RiftServer and the
	client's loading cover. PodIndex says which pad is theirs.

	  PodServer.start(site)   site: OutpostServer.site() (its Pads)
	  PodServer.spawnFor(player) -> CFrame?
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Pods = require(ReplicatedStorage.Shared.Pods)

local PodServer = {}

local STEEL = Color3.fromRGB(128, 134, 146)
local DARK = Color3.fromRGB(58, 62, 72)

local pads = {} -- { { Index, Tier, CFrame, Model } }
local byIndex = {}
local taken: { [number]: Player | true } = {} -- (true: a pod still lifting off)
local podOf: { [Player]: { Index: number, Model: Model, Entry: any } } = {}
-- Pods on the move: { Model, Pad (CFrame), Kind ("Land" | "Lift"), T, From }
local moving = {}
local rng = Random.new()
local scrapped = setmetatable({}, { __mode = "k" }) -- (pods gone for good)

-- A pod gone for good: its pad free again (unless someone has it already).
local function scrap(model: Model, index: number)
	if not scrapped[model] then
		scrapped[model] = true
		model:Destroy()
	end
	if taken[index] == true then
		taken[index] = nil
	end
end
local function standing(model: Model): boolean
	return not scrapped[model] and model.Parent ~= nil
end

local function part(parent, cframe: CFrame, size: Vector3, color: Color3, material, shape: string?)
	local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
	if shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	elseif shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	end
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CFrame, p.Size, p.Color = cframe, size, color
	p.Material = material or Enum.Material.Metal
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local UP = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder standing up)

-- The pod, built standing on `pad` (its door toward the Heart): a white
-- habitat module with a rounded roof, warm-lit double doors and windows,
-- an antenna with a beacon in the owner's colour, a stair down to the pad
-- and blue thrusters under it (lit only in flight). Its display stall
-- stands beside it once it's down (`display`).
local WHITE = Color3.fromRGB(226, 228, 232)
local WARM = Color3.fromRGB(255, 196, 96)
local JET = Color3.fromRGB(120, 190, 255)
local CYAN = Color3.fromRGB(110, 220, 255)
local function build(player: Player, pad): Model
	local f = pad.CFrame
	local color = Pods.colorFor(player.UserId)
	-- (drawn at Pods.Scale: these are the sizes before it)
	local K = Pods.Scale
	local function F(x, y, z)
		return f * CFrame.new(x * K, y * K, z * K)
	end
	local function V(x, y, z)
		return Vector3.new(x * K, y * K, z * K)
	end
	local w, d, base = Pods.Width / K, Pods.Hull * 2 / K, Pods.Base / K
	local model = Instance.new("Model")
	model.Name = "Pod"
	-- the skirt it stands on, the body and its rounded roof
	local skirt = part(model, F(0, base / 2, 0), V(w - 1, base, d - 0.6), DARK, Enum.Material.Metal)
	skirt.CanCollide, skirt.CanQuery = true, true
	local body = part(model, F(0, base + 2.3, 0), V(w, 4.6, d), WHITE, Enum.Material.SmoothPlastic)
	body.Name = "Hull"
	body.CanCollide, body.CanQuery = true, true
	model.PrimaryPart = body
	local roofY = base + 4.6
	part(model, F(0, roofY + 0.7, 0), V(w, 1.4, d - 2.8), WHITE, Enum.Material.SmoothPlastic)
	for _, side in { -1, 1 } do
		-- (a cylinder lies along X: the roof's rounded edges)
		part(model, F(0, roofY, side * (d / 2 - 1.4)), V(w, 2.8, 2.8), WHITE, Enum.Material.SmoothPlastic, "Cylinder")
		-- dark end panels and a trim band round the bottom
		part(model, F(side * (w / 2 + 0.05), base + 2.6, 0), V(0.3, 5, d - 1), DARK, Enum.Material.Metal)
	end
	part(model, F(0, base + 0.35, 0), V(w + 0.2, 0.5, d + 0.2), DARK, Enum.Material.Metal)
	-- the front: double doors and two windows, lit warm
	local front = -d / 2
	part(model, F(0, base + 2.1, front - 0.1), V(3.8, 4.1, 0.3), DARK, Enum.Material.Metal)
	local door = part(model, F(0, base + 2, front - 0.2), V(3.1, 3.7, 0.2), WARM, Enum.Material.Neon)
	door.Name = "Door"
	part(model, F(0, base + 2, front - 0.3), V(0.15, 3.7, 0.1), DARK, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		part(model, F(side * 3.3, base + 2.7, front - 0.1), V(2.3, 1.8, 0.3), DARK, Enum.Material.Metal)
		part(model, F(side * 3.3, base + 2.7, front - 0.2), V(1.9, 1.4, 0.2), WARM, Enum.Material.Neon)
	end
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = WARM, 14, 0.9
	glow.Parent = door
	-- the roof: a vent box and the antenna with its beacon
	part(model, F(-w / 4, roofY + 1.7, 0.6), V(2.4, 0.6, 1.8), STEEL, Enum.Material.Metal)
	part(model, F(w / 5, roofY + 2.5, 0.8), V(0.3, 2.2, 0.3), DARK, Enum.Material.Metal)
	local beacon = part(model, F(w / 5, roofY + 3.9, 0.8), V(0.8, 0.8, 0.8), color, Enum.Material.Neon)
	beacon.Name = "Beacon"
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, 16, 1.2
	light.Parent = beacon
	-- the stair down from the doors to the pad
	local steps = 4
	local run = Pods.Ramp / K / steps
	for i = 1, steps do
		local top = base * (1 - (i - 1) / steps)
		local step = part(
			model,
			F(0, top / 2, front - (i - 0.5) * run),
			V(3.6, top, run),
			STEEL,
			Enum.Material.DiamondPlate
		)
		step.Name = if i == 1 then "Ramp" else "Step"
		step.CanCollide, step.CanQuery = true, true
	end
	for _, side in { -1, 1 } do
		local from = (F(side * 1.9, base + 1.2, front - 0.2)).Position
		local to = (F(side * 1.9, 1.2, front - Pods.Ramp / K)).Position
		part(model, CFrame.lookAt((from + to) / 2, to), Vector3.new(0.15 * K, 0.15 * K, (to - from).Magnitude), DARK, Enum.Material.Metal)
	end
	-- the thrusters, lit only on the way down or up
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local jet = part(model, F(x * (w / 2 - 1.6), -1.1, z * (d / 2 - 1.4)), V(0.9, 2.2, 0.9), JET, Enum.Material.Neon)
			jet.Name = "Thruster"
			jet.Transparency = 1
		end
	end
	-- whose it is (sized in studs: small from afar)
	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.new(7, 0, 1.1, 0)
	plate.StudsOffsetWorldSpace = V(0, 4.6 + 1.2, 0)
	plate.MaxDistance = 90
	plate.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(20, 22, 30)
	label.TextStrokeTransparency = 0.3
	label.Text = player.DisplayName
	label.Parent = plate
	plate.Parent = body
	model:SetAttribute("OwnerId", player.UserId)
	model.Parent = pad.Model
	return model
end

-- The display stall beside the pod, once it's down: posts, an awning lit
-- warm underneath, a counter (where the owner's favourite things will go)
-- and a couple of crates.
local WOOD = Color3.fromRGB(120, 86, 58)
local function display(pad): Model
	local f = pad.CFrame
	local K = Pods.Scale
	local function F(x, y, z)
		return f * CFrame.new(x * K, y * K, z * K)
	end
	local function V(x, y, z)
		return Vector3.new(x * K, y * K, z * K)
	end
	local stall = Instance.new("Model")
	stall.Name = "Display"
	local x, z = Pods.Width / K / 2 + 1.7, 0.8
	local counter = part(stall, F(x, 0.6, z - 1), V(2.8, 1.2, 2), WOOD, Enum.Material.WoodPlanks)
	counter.Name = "Counter"
	counter.CanCollide, counter.CanQuery = true, true
	part(stall, F(x, 1.25, z - 1), V(3, 0.1, 2.2), DARK, Enum.Material.Metal)
	for _, dx in { -1.4, 1.4 } do
		part(stall, F(x + dx, 1.8, z - 2.2), V(0.25, 3.6, 0.25), DARK, Enum.Material.Metal)
		part(stall, F(x + dx, 1.8, z + 0.4), V(0.25, 3.6, 0.25), DARK, Enum.Material.Metal)
	end
	part(stall, F(x, 3.7, z - 0.9) * CFrame.Angles(math.rad(-12), 0, 0), V(3.6, 0.25, 3.4), DARK, Enum.Material.Metal)
	local strip = part(stall, F(x, 3.4, z - 2.4), V(3.4, 0.18, 0.18), WARM, Enum.Material.Neon)
	local lamp = Instance.new("PointLight")
	lamp.Color, lamp.Range, lamp.Brightness = WARM, 10, 0.8
	lamp.Parent = strip
	part(stall, F(x + 0.2, 0.5, z + 1.4), V(1, 1, 1), WOOD, Enum.Material.WoodPlanks)
	part(stall, F(x - 1, 0.4, z + 1.6) * CFrame.Angles(0, math.rad(20), 0), V(0.8, 0.8, 0.8), WOOD, Enum.Material.WoodPlanks)
	local cyan = part(stall, F(x - 1, 1.55, z - 1.5), V(0.35, 0.5, 0.35), CYAN, Enum.Material.Neon)
	cyan.Name = "Lantern"
	stall.Parent = pad.Model
	return stall
end

-- (the pod's pivot is its Hull, `Rest` where it stands on the pad)
local function setHeight(entry, height: number)
	if standing(entry.Model) and entry.Model.PrimaryPart then
		entry.Model:PivotTo(CFrame.new(0, height, 0) * entry.Rest) -- (world up: the hull stands turned)
	end
end
local function thruster(model: Model, on: boolean)
	for _, jet in model:GetChildren() do
		if jet.Name == "Thruster" then
			(jet :: BasePart).Transparency = if on then 0.15 else 1
		end
	end
end
local function landed(entry)
	setHeight(entry, 0)
	thruster(entry.Model, false)
	entry.Model:SetAttribute("Landed", true)
	if not entry.Display and entry.PadInfo then
		entry.Display = display(entry.PadInfo)
	end
end

-- One step of everything on the move (RunService.Heartbeat).
function PodServer._step(dt: number)
	for i = #moving, 1, -1 do
		local entry = moving[i]
		entry.T += dt
		if not standing(entry.Model) then
			table.remove(moving, i)
		elseif entry.Kind == "Land" then
			if entry.T >= Pods.Landing.Fall then
				table.remove(moving, i)
				landed(entry)
			else
				setHeight(entry, Pods.altitude(entry.T))
			end
		else
			if entry.T >= Pods.Landing.LiftOff then
				table.remove(moving, i)
				scrap(entry.Model, entry.Index)
			else
				setHeight(entry, entry.From + Pods.lift(entry.T))
			end
		end
	end
end

local function friendIds(player: Player): { [number]: boolean }
	local ids = {}
	pcall(function()
		local pages = Players:GetFriendsAsync(player.UserId)
		for _ = 1, 4 do
			for _, friend in pages:GetCurrentPage() do
				ids[friend.Id] = true
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	return ids
end

local function arrive(player: Player)
	if podOf[player] or #pads == 0 then
		return
	end
	local friends = friendIds(player)
	if not player.Parent then
		return -- (left while we asked)
	end
	local near = {}
	for other, pod in podOf do
		if friends[other.UserId] then
			table.insert(near, pod.Index)
		end
	end
	local index = Pods.choose(pads, taken, near, rng)
	if not index or podOf[player] then
		return -- (every pad taken: the Shelter's spawn it is)
	end
	local pad = byIndex[index]
	taken[index] = player
	local model = build(player, pad)
	local entry = { Model = model, Pad = pad.CFrame, Rest = model:GetPivot(), Kind = "Land", T = 0, Index = index, PadInfo = pad }
	podOf[player] = { Index = index, Model = model, Entry = entry }
	player:SetAttribute("PodIndex", index)
	player:SetAttribute("PodSpawn", Pods.spawnAt(pad.CFrame))
	setHeight(entry, Pods.Landing.Height)
	thruster(model, true)
	table.insert(moving, entry)
	-- On its pad by now whatever happens.
	task.delay(Pods.Landing.Failsafe, function()
		local i = table.find(moving, entry)
		if i then
			table.remove(moving, i)
		end
		local still = podOf[player]
		if still and still.Entry == entry and standing(model) then -- (not lifting off already)
			landed(entry)
		end
	end)
end

local function depart(player: Player)
	local pod = podOf[player]
	podOf[player] = nil
	if not pod then
		return
	end
	taken[pod.Index] = true -- (free once it's gone)
	local entry = pod.Entry
	entry.PadInfo = nil -- (no stall going up after this)
	if entry.Display then
		entry.Display:Destroy() -- (packed up first)
		entry.Display = nil
	end
	local from = 0
	local i = table.find(moving, entry)
	if i then
		table.remove(moving, i)
		from = Pods.altitude(entry.T) -- (still coming down: up from there)
	end
	local lift = { Model = pod.Model, Rest = entry.Rest, Kind = "Lift", T = 0, From = from, Index = pod.Index }
	thruster(pod.Model, true)
	table.insert(moving, lift)
	task.delay(Pods.Landing.LiftOff + 2, function()
		scrap(pod.Model, pod.Index)
	end)
end

function PodServer.spawnFor(player: Player): CFrame?
	local at = player:GetAttribute("PodSpawn")
	return if typeof(at) == "CFrame" then at else nil
end

function PodServer.start(site)
	if not site or not site.Pads then
		return
	end
	pads = site.Pads
	for _, pad in pads do
		byIndex[pad.Index] = pad
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(arrive, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(arrive, player)
	end
	Players.PlayerRemoving:Connect(depart)
	RunService.Heartbeat:Connect(PodServer._step)
end

-- For tests.
PodServer._arrive, PodServer._depart = arrive, depart
PodServer._podOf, PodServer._taken = podOf, taken

return PodServer
