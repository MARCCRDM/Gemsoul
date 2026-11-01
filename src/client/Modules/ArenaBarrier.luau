--[[
	The Arena's barrier: while you're fighting on its floor (an Arena session:
	a rival, the intro rounds, sparring; or a duel), a ring of force field
	stands round the floor's edge so you can't walk off it by accident (which
	ends the session: Server.ArenaSessions). LEAVE is the way out.

	It's built on your own screen only: your character is yours to move, so
	it stops you and nobody else (a duel's foe has their own). It shows as a
	faint field, lit where you come near it.

	  ArenaBarrier.start()              once (Lobby.client)
	  ArenaBarrier.ring(center, radius, count) -> { CFrame }   each panel's
	                                    place round the floor (pure)
	  ArenaBarrier.Height, Gap, Panels
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
	local center = marks and marks:GetAttribute("ArenaFloor")
	local radius = marks and marks:GetAttribute("ArenaRadius")
	if typeof(center) ~= "Vector3" or type(radius) ~= "number" then
		return nil, nil
	end
	return center, radius
end

local function build()
	if folder then
		return
	end
	local center, radius = landmarks()
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
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius + 1 and math.abs(offset.Y) < 30
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
