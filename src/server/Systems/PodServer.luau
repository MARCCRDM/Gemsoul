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
local HAZARD = Color3.fromRGB(240, 178, 48)
local FLAME = Color3.fromRGB(255, 150, 60)

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

-- The pod, built standing on `pad` (its ramp out toward the Heart): a hull
-- with a dome, a hazard band, three legs, a lit doorway over the ramp, a
-- beacon in the owner's colour and their name over it.
local function build(player: Player, pad): Model
	local f = pad.CFrame
	local color = Pods.colorFor(player.UserId)
	local hull = Pods.Hull
	local model = Instance.new("Model")
	model.Name = "Pod"
	local body = part(model, f * CFrame.new(0, 6.5, 0) * UP, Vector3.new(10, hull * 2, hull * 2), STEEL, Enum.Material.Metal, "Cylinder")
	body.Name = "Hull"
	body.CanCollide, body.CanQuery = true, true
	model.PrimaryPart = body
	part(model, f * CFrame.new(0, 3.2, 0) * UP, Vector3.new(1, hull * 2 + 0.3, hull * 2 + 0.3), HAZARD, Enum.Material.SmoothPlastic, "Cylinder")
	part(model, f * CFrame.new(0, 11.5, 0), Vector3.new(hull * 2, hull * 2, hull * 2), STEEL, Enum.Material.Metal, "Ball")
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2 + math.pi / 3
		local foot = f * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, hull + 1.4)
		part(model, foot * CFrame.new(0, 1.6, -0.6) * CFrame.Angles(math.rad(-25), 0, 0), Vector3.new(0.8, 3.6, 0.8), DARK)
		part(model, foot * CFrame.new(0, 0.2, 0), Vector3.new(2.2, 0.4, 2.2), DARK)
	end
	-- the doorway and the ramp down from it
	local door = part(model, f * CFrame.new(0, 5, -hull + 0.1), Vector3.new(4, 6.5, 0.4), color, Enum.Material.Neon)
	door.Name = "Door"
	door.Transparency = 0.25
	local ramp = part(
		model,
		f * CFrame.new(0, 0.9, -(hull + Pods.Ramp / 2)),
		Vector3.new(4.4, 1.8, Pods.Ramp),
		DARK,
		Enum.Material.DiamondPlate,
		"Wedge"
	)
	ramp.Name = "Ramp"
	ramp.CanCollide, ramp.CanQuery = true, true
	-- the beacon
	part(model, f * CFrame.new(0, 17.3, 0), Vector3.new(0.5, 1.8, 0.5), DARK)
	local beacon = part(model, f * CFrame.new(0, 18.6, 0) * UP, Vector3.new(0.9, 1.8, 1.8), color, Enum.Material.Neon, "Cylinder")
	beacon.Name = "Beacon"
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = color, 22, 1.4
	glow.Parent = beacon
	-- the thruster, lit only on the way down or up
	local flame = part(model, f * CFrame.new(0, -1.5, 0), Vector3.new(3, 4, 3), FLAME, Enum.Material.Neon)
	flame.Name = "Thruster"
	flame.Transparency = 1
	-- whose it is
	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.fromOffset(220, 34)
	plate.StudsOffsetWorldSpace = Vector3.new(0, 15, 0)
	plate.MaxDistance = 140
	plate.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = player.DisplayName
	label.Parent = plate
	plate.Parent = body
	model:SetAttribute("OwnerId", player.UserId)
	model.Parent = pad.Model
	return model
end

-- (the pod's pivot is its Hull, `Rest` where it stands on the pad)
local function setHeight(entry, height: number)
	if standing(entry.Model) and entry.Model.PrimaryPart then
		entry.Model:PivotTo(CFrame.new(0, height, 0) * entry.Rest) -- (world up: the hull stands turned)
	end
end
local function thruster(model: Model, on: boolean)
	local flame = model:FindFirstChild("Thruster")
	if flame then
		(flame :: BasePart).Transparency = if on then 0.2 else 1
	end
end
local function landed(entry)
	setHeight(entry, 0)
	thruster(entry.Model, false)
	entry.Model:SetAttribute("Landed", true)
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
	local entry = { Model = model, Pad = pad.CFrame, Rest = model:GetPivot(), Kind = "Land", T = 0, Index = index }
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
