--[[
	The Arena's barrier: while you're fighting on its floor (an Arena session:
	a rival, the intro rounds, sparring; or a duel), a ring of force field
	stands round the floor's edge so you can't walk off it by accident (which
	ends the session: Server.ArenaSessions). LEAVE is the way out.

	It's built on your own screen only: your character is yours to move, so
	it stops you and nobody else (a duel's foe has their own). It shows as a
	faint field, lit where you come near it.

	The entrance is shut too, while you fight: a gate door between its two
	pillars (Server World/Zones/Arena's GatePillar), up to the lintel, in
	the Arena's sapphire marble, so there's no hole in the wall behind your
	foe (with the Outpost, and whoever's there, showing through it).

	  ArenaBarrier.start()              once (Lobby.client)
	  ArenaBarrier.ring(center, radius, count) -> { CFrame }   each panel's
	                                    place round the floor (pure)
	  ArenaBarrier.Height, Gap, Panels, DoorHeight, Door
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaBarrier = {}

ArenaBarrier.Height = 18 -- studs tall (no jumping over it)
ArenaBarrier.Gap = 1.5 -- studs outside the floor's edge (the server's own bound is +2)
ArenaBarrier.Panels = 40
ArenaBarrier.Thick = 1.2
ArenaBarrier.Color = Color3.fromRGB(110, 210, 255)
ArenaBarrier.Near = 10 -- studs: a panel this close lights up
-- Through it anyway (a dash or a knock-back past the field): put back
-- inside, Back studs in from the floor's edge. Only this close past it:
-- further is the server's own move (LEAVE, back to the Outpost).
ArenaBarrier.Hold = 12
ArenaBarrier.Back = 1.5
ArenaBarrier.DoorHeight = 17 -- studs: up to the gate's lintel (World/Zones/Arena: WALL_HEIGHT - 3)
ArenaBarrier.Door = { Stone = Color3.fromRGB(29, 58, 100), Seam = Color3.fromRGB(118, 215, 245), Band = Color3.fromRGB(225, 185, 107) }

local player = Players.LocalPlayer

-- Each panel's place: standing on the ring round `center`, facing in.
function ArenaBarrier.ring(center: Vector3, radius: number, count: number): { CFrame }
	local out = {}
	for i = 0, count - 1 do
		local angle = (i + 0.5) / count * math.pi * 2
		local at = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		table.insert(out, CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z)))
	end
	return out
end

local folder: Folder? = nil
local panels: { BasePart } = {}

local function landmarks(): (Vector3?, number?)
	local marks = ReplicatedStorage:FindFirstChild("Landmarks")
	-- (a Training session's private copy of the Arena: Server.PrivateArenas)
	local own = game:GetService("Players").LocalPlayer:GetAttribute("ArenaCenter")
	local center = if typeof(own) == "Vector3" then own else marks and marks:GetAttribute("ArenaFloor")
	local radius = marks and marks:GetAttribute("ArenaRadius")
	if typeof(center) ~= "Vector3" or type(radius) ~= "number" then
		return nil, nil
	end
	return center, radius
end

-- The entrance's two pillars, round the Arena's floor.
local function gatePillars(center: Vector3, radius: number): (BasePart?, BasePart?)
	local found = {}
	for _, d in workspace:GetDescendants() do
		if d.Name == "GatePillar" and d:IsA("BasePart") then
			local offset = d.Position - center
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius + 25 then
				table.insert(found, d)
			end
		end
	end
	if #found ~= 2 then
		return nil, nil
	end
	return found[1], found[2]
end

-- The door: between the pillars' inner faces, floor to lintel, facing in.
local function door(parent: Instance, center: Vector3, radius: number)
	local a, b = gatePillars(center, radius)
	if not a or not b then
		return
	end
	local floorY = math.min(a.Position.Y - a.Size.Y / 2, b.Position.Y - b.Size.Y / 2)
	local top = floorY + ArenaBarrier.DoorHeight
	local mid = (a.Position + b.Position) / 2
	local across = Vector3.new(b.Position.X - a.Position.X, 0, b.Position.Z - a.Position.Z)
	local width = across.Magnitude - math.min(a.Size.X, a.Size.Z) + 0.4
	local base = CFrame.lookAt(Vector3.new(mid.X, floorY, mid.Z), Vector3.new(center.X, floorY, center.Z))
	local function slab(name: string, size: Vector3, at: CFrame, color: Color3, material: Enum.Material, collide: boolean)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = collide
		part.CanQuery = false
		part.CanTouch = false
		part.Size = size
		part.CFrame = base * at
		part.Color = color
		part.Material = material
		part.Parent = parent
		return part
	end
	local height = top - floorY
	local look = ArenaBarrier.Door
	slab("GateDoor", Vector3.new(width, height, 2), CFrame.new(0, height / 2, 0), look.Stone, Enum.Material.Marble, true)
	-- (on its inner face: the seam where its two leaves meet, a gold band
	-- across, and a darker plinth)
	slab("GateSeam", Vector3.new(0.35, height - 2, 0.2), CFrame.new(0, height / 2 + 1, -1.05), look.Seam, Enum.Material.Neon, false)
	slab("GateBand", Vector3.new(width, 0.6, 0.2), CFrame.new(0, height * 0.62, -1.05), look.Band, Enum.Material.Metal, false)
	slab("GatePlinth", Vector3.new(width, 1.2, 2.4), CFrame.new(0, 0.6, 0), look.Stone:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Marble, false)
end

local function build()
	local center, radius = landmarks()
	if folder and folder:GetAttribute("Center") == center then
		return
	end
	if folder then
		-- (its floor moved: a private copy of the Arena, or back: Server.PrivateArenas)
		folder:Destroy()
		folder = nil
	end
	if not center or not radius then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "ArenaBarrier"
	local r = radius + ArenaBarrier.Gap
	local width = 2 * math.pi * r / ArenaBarrier.Panels + 0.3
	table.clear(panels)
	for _, frame in ArenaBarrier.ring(center, r, ArenaBarrier.Panels) do
		local p = Instance.new("Part")
		p.Name = "Field"
		p.Anchored = true
		p.CanCollide = true
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.ForceField
		p.Color = ArenaBarrier.Color
		p.Transparency = 0.9
		p.Size = Vector3.new(width, ArenaBarrier.Height, ArenaBarrier.Thick)
		p.CFrame = frame * CFrame.new(0, ArenaBarrier.Height / 2 - 1, 0)
		p.Parent = f
		table.insert(panels, p)
	end
	pcall(door, f, center, radius)
	f:SetAttribute("Center", center)
	f:SetAttribute("Radius", radius)
	f.Parent = workspace
	folder = f
end

local function clear()
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(panels)
end

-- On the Arena's floor in a fight of its own: the barrier's up.
local function wanted(): boolean
	if player:GetAttribute("DungeonId") or player:GetAttribute("RiftRun") or player:GetAttribute("RaidId") then
		return false
	end
	if player:GetAttribute("CombatSession") == nil and player:GetAttribute("MatchId") == nil then
		return false
	end
	local center, radius = landmarks()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not center or not radius or not root then
		return false
	end
	local offset = root.Position - center
	-- (up already: kept up a little past the edge, so the hold below can
	-- put them back)
	local reach = radius + (if folder then ArenaBarrier.Hold else 1)
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= reach and math.abs(offset.Y) < 30
end

-- Past the field's inner face but not far (ArenaBarrier.Hold): where to put
-- them back (nil: where they are is fine). Pure.
function ArenaBarrier.held(position: Vector3, center: Vector3, radius: number): Vector3?
	local offset = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
	local distance = offset.Magnitude
	if distance <= radius + ArenaBarrier.Gap - ArenaBarrier.Thick / 2 or distance > radius + ArenaBarrier.Hold then
		return nil
	end
	local inward = offset.Unit * (radius - ArenaBarrier.Back)
	return Vector3.new(center.X + inward.X, position.Y, center.Z + inward.Z)
end

local started = false
function ArenaBarrier.start()
	if started then
		return
	end
	started = true
	local nextCheck = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= nextCheck then
			nextCheck = now + 0.25
			if wanted() then
				build()
			else
				clear()
			end
		end
		-- Lit where you come near it.
		if folder then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local center, radius = folder:GetAttribute("Center"), folder:GetAttribute("Radius")
			if root and typeof(center) == "Vector3" and type(radius) == "number" then
				local back = ArenaBarrier.held(root.Position, center, radius)
				if back then
					root.CFrame = CFrame.new(back) * root.CFrame.Rotation
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
			if root then
				for _, p in panels do
					local d = (Vector3.new(p.Position.X, root.Position.Y, p.Position.Z) - root.Position).Magnitude
					p.Transparency = 0.9 - 0.55 * math.clamp(1 - d / ArenaBarrier.Near, 0, 1)
				end
			end
		end
	end)
end

return ArenaBarrier
