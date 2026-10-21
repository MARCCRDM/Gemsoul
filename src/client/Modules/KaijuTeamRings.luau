--[[
	A kaiju in a battle stands on a ring in its side's colour: BLUE for
	side A, RED for side B (Shared.KaijuBattle.Sides), so you can tell the
	two teams apart at a glance, from the court or the stands. The server
	marks each kaiju brought to a battle with its side (the model's
	KaijuTeam attribute, Server.KaijuBattles) and clears it once it's over;
	everyone sees the rings, players and onlookers alike.

	  KaijuTeamRings.start()            once (Lobby.client)
	  KaijuTeamRings.size(extent) -> n  a ring's width for a body that wide
	                                    (pure: tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local KaijuBattle = require(ReplicatedStorage.Shared.KaijuBattle)

local KaijuTeamRings = {}

KaijuTeamRings.Transparency = 0.35
KaijuTeamRings.Rescan = 0.5 -- seconds between looks for kaiju newly marked

-- A ring a little wider than the body it's under (4 to 10 studs).
function KaijuTeamRings.size(extent: number): number
	return math.clamp(extent * 1.1, 4, 10)
end

type Ring = { Model: Model, Root: BasePart, Disc: Part, Edge: Part, Side: string }

local rings: { [Model]: Ring } = {}
local folder: Folder? = nil
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function part(name: string, color: Color3, width: number, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Shape = Enum.PartType.Cylinder
	p.Color = color
	p.Transparency = transparency
	p.Size = Vector3.new(0.06, width, width)
	return p
end

local function drop(model: Model)
	local ring = rings[model]
	if ring then
		ring.Disc:Destroy()
		ring.Edge:Destroy()
		rings[model] = nil
	end
end

local function add(model: Model, side: string)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "KaijuTeamRings"
		folder.Parent = workspace
	end
	local spec = KaijuBattle.Sides[side]
	local color = if spec then spec.Color else Color3.new(1, 1, 1)
	local size = model:GetExtentsSize()
	local width = KaijuTeamRings.size(math.max(size.X, size.Z))
	-- (A bright rim round a darker fill of the colour.)
	local edge = part("Rim", color, width, 0.1)
	local disc = part("Ring", color:Lerp(Color3.new(0, 0, 0), 0.55), width - 0.8, KaijuTeamRings.Transparency)
	edge.Parent, disc.Parent = folder, folder
	rings[model] = { Model = model, Root = root, Disc = disc, Edge = edge, Side = side }
end

-- Every kaiju marked with a side gets a ring; one no longer marked (or
-- gone) loses it.
local function scan()
	local kaiju = workspace:FindFirstChild("Kaiju")
	local seen = {}
	if kaiju then
		for _, model in kaiju:GetChildren() do
			local side = model:IsA("Model") and model:GetAttribute("KaijuTeam")
			if type(side) == "string" then
				seen[model] = true
				local ring = rings[model]
				if ring and ring.Side ~= side then
					drop(model)
					ring = nil
				end
				if not ring then
					add(model, side)
				end
			end
		end
	end
	for model in rings do
		if not seen[model] then
			drop(model)
		end
	end
	-- (The floor is what's under them: not kaiju, rings or anyone.)
	local skip: { Instance } = { folder or workspace.Terrain }
	if kaiju then
		table.insert(skip, kaiju)
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	local field = workspace:FindFirstChild("KaijuBattleField")
	if field then
		table.insert(skip, field)
	end
	params.FilterDescendantsInstances = skip
end

-- Each ring under its kaiju, on the floor beneath it.
local function follow()
	if not next(rings) then
		return
	end
	for model, ring in rings do
		if not ring.Root.Parent then
			drop(model)
		else
			local at = ring.Root.Position
			local hit = workspace:Raycast(at, Vector3.new(0, -14, 0), params)
			local y = if hit then hit.Position.Y else at.Y - 2
			local cf = CFrame.new(at.X, y + 0.06, at.Z) * CFrame.Angles(0, 0, math.rad(90))
			ring.Edge.CFrame = cf
			ring.Disc.CFrame = cf * CFrame.new(0.02, 0, 0)
		end
	end
end

local started = false
function KaijuTeamRings.start()
	if started then
		return
	end
	started = true
	local nextScan = 0
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now >= nextScan then
			nextScan = now + KaijuTeamRings.Rescan
			scan()
		end
		follow()
	end)
end

return KaijuTeamRings
