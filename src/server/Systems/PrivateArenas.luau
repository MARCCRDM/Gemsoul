--[[
	Private arenas: a copy of the Arena (workspace.CombatArena) of one's own
	for every Training session (a new miner's first fight and intro rounds,
	a practice bout), far from everyone else's, so nobody walks into another
	player's fight, sees it, or hears it. Duels (Server.Duels) take a ring
	of Arena Row (claimStage), the Grand Arena first; PvP and raids keep the
	shared Arena, and duels too when every ring's taken.

	A copy is the Arena's scenery only: no vendors, prompts, scripts, spawn
	pads or tags. Copies are kept for reuse once their fight's over (a few
	of them, Spare), and lined up Gap studs apart along X from Origin (well
	clear of the town, the mine, the dungeons and the Rift).

	The copy's floor, where the Arena's ArenaFloor is in it, is the
	player's ArenaCenter attribute (Shared.Combat.arenaCenter): the rival
	steps in there (Server.Duelist), the barrier rings it (Client
	ArenaBarrier), and the floor counts as the Arena (Shared.Combat.inArena,
	by each copy's Center attribute under workspace.PrivateArenas).

	  PrivateArenas.claim(player) -> Vector3?   the floor's centre of a copy
	                                            of their own (nil if there's
	                                            no Arena to copy)
	  PrivateArenas.claimStage(players, prefer?) -> Vector3?   a free ring of
	                                            Arena Row for all of them (a
	                                            duel), `prefer` (its name) first
	                                            (nil: none free)
	  PrivateArenas.rings() -> { { Name, Fighters } }   Arena Row now
	  PrivateArenas.release(player)             their copy, back to the spares
	                                            (a ring: free once all its
	                                            fighters are out)
	  PrivateArenas.stage(name, ground, reach)  an open ring built for good
	                                            at `ground` (Arena Row in the
	                                            Outpost: Shared.Outpost.
	                                            Settlement.Stages): a floor on
	                                            the ground, no walls, so the
	                                            fight's seen and sees out;
	                                            claimed first; a see-through
	                                            barrier round it, always up
	  PrivateArenas.start()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local PrivateArenas = {}
PrivateArenas.Origin = Vector3.new(0, 0, -6000) -- (from the Arena's own floor)
PrivateArenas.Gap = 1500 -- studs between copies: none streams in with another
PrivateArenas.Spare = 3 -- copies kept for reuse

local STRIP = {
	ProximityPrompt = true,
	ClickDetector = true,
	Script = true,
	LocalScript = true,
	ModuleScript = true,
	Sound = true,
	SpawnLocation = true,
	Seat = true,
	VehicleSeat = true,
}

local owned = {} :: { [Player]: Model }
-- Arena Row's copies: { Name, Model, Center, Fence, Owner, Holders }, in the
-- order they're taken (Holders: everyone fighting in it).
local stages = {}
local spares = {} :: { Model }
local used = {} :: { [number]: boolean }

local function folder(): Folder
	local found = workspace:FindFirstChild("PrivateArenas")
	if not found then
		found = Instance.new("Folder")
		found.Name = "PrivateArenas"
		found.Parent = workspace
	end
	return found :: Folder
end

local function floor(): Vector3?
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local center = landmarks and landmarks:GetAttribute("ArenaFloor")
	return if typeof(center) == "Vector3" then center else nil
end

local function freeSlot(): number
	local slot = 1
	while used[slot] do
		slot += 1
	end
	return slot
end

-- A fresh copy of the Arena's scenery, `offset` from it.
local function copy(source: Instance, offset: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "PrivateArena"
	for _, child in source:GetChildren() do
		local ok, clone = pcall(function()
			return child:Clone()
		end)
		if ok and clone then
			clone.Parent = model
		end
	end
	-- (The scenery only: anything that acts, talks or spawns stays behind,
	-- and nothing in it answers to a tag: vendors, queues and the like.)
	local drop = {}
	for _, d in model:GetDescendants() do
		if STRIP[d.ClassName] or (d:IsA("Model") and d:FindFirstChildOfClass("Humanoid")) then
			table.insert(drop, d)
		end
	end
	for _, d in drop do
		pcall(d.Destroy, d)
	end
	for _, d in model:GetDescendants() do
		for _, tag in CollectionService:GetTags(d) do
			CollectionService:RemoveTag(d, tag)
		end
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CFrame = d.CFrame + offset
		end
	end
	return model
end

-- The barrier round a stage's floor, `reach` out: a see-through wall of
-- force field in the ring's colour, always up: nobody walks in or out (the
-- fighters are put inside). It stops no camera and no blow (CanQuery off).
PrivateArenas.BarrierHeight = 14
local function fenceOf(model: Model, center: Vector3, reach: number, glow: Color3): Folder
	local fence = Instance.new("Folder")
	fence.Name = "StageFence"
	local segments = 24
	for i = 0, segments - 1 do
		local a = (i + 0.5) / segments * math.pi * 2
		local p = Instance.new("Part")
		p.Name = "Fence"
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, true, false, false
		p.Material = Enum.Material.ForceField
		p.Color = glow
		p.Transparency = 0.2
		p.CastShadow = false
		local tall = PrivateArenas.BarrierHeight
		p.Size = Vector3.new(2 * reach * math.tan(math.pi / segments) + 0.2, tall, 0.6)
		p.CFrame = CFrame.new(center + Vector3.new(math.cos(a) * reach, tall / 2 - 0.7, math.sin(a) * reach))
			* CFrame.Angles(0, -a + math.pi / 2, 0)
		p.Parent = fence
	end
	fence.Parent = model
	return fence
end
local function fenced(_stage, _on: boolean)
	-- (the barrier stays up, fight or no fight)
end

-- An open ring on the ground: the fight floor (as wide as the Arena's), a
-- lit edge and a hazard kerb, short lamp posts round it; nothing to hide
-- the fight or the Outpost from it. Its floor's top is at `target`.
PrivateArenas.RingColors = {
	GrandArena = Color3.fromRGB(255, 120, 70),
	IntroRing = Color3.fromRGB(110, 220, 255),
	DuelRingWest = Color3.fromRGB(190, 120, 255),
	DuelRingEast = Color3.fromRGB(120, 235, 140),
}
local function ringAt(name: string, target: Vector3, radius: number): Model
	local model = Instance.new("Model")
	model.Name = name
	local glow = PrivateArenas.RingColors[name] or Color3.fromRGB(110, 220, 255)
	local function piece(partName: string, cframe: CFrame, size: Vector3, color: Color3, material, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = partName
		p.Anchored = true
		p.CanTouch = false
		if shape then
			p.Shape = shape
		end
		p.Size, p.CFrame, p.Color, p.Material = size, cframe, color, material
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local flat = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder lying as a disc)
	-- the floor, its top at `target`; on it the lit edge, the inlay over all
	-- but the edge's rim (so the edge glows as a ring), a mark in the middle
	piece("Floor", CFrame.new(target - Vector3.new(0, 0.35, 0)) * flat, Vector3.new(0.7, radius * 2 + 4, radius * 2 + 4),
		Color3.fromRGB(58, 62, 74), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	for _, spec in {
		{ "Edge", 0.01, radius * 2 + 0.6, glow, Enum.Material.Neon },
		{ "Inlay", 0.02, radius * 2 - 0.4, Color3.fromRGB(42, 46, 58), Enum.Material.SmoothPlastic },
		{ "Mark", 0.03, 5, glow, Enum.Material.Neon },
	} do
		local disc = piece(spec[1], CFrame.new(target + Vector3.new(0, spec[2], 0)) * flat, Vector3.new(0.04, spec[3], spec[3]), spec[4], spec[5], Enum.PartType.Cylinder)
		disc.CanCollide, disc.CanQuery = false, false
	end
	-- the kerb, and lamp posts round it
	local posts = 10
	for i = 0, posts - 1 do
		local a = i / posts * math.pi * 2
		local at = target + Vector3.new(math.cos(a) * (radius + 2.6), 0, math.sin(a) * (radius + 2.6))
		piece("Post", CFrame.new(at + Vector3.new(0, 2.4, 0)), Vector3.new(0.8, 5, 0.8), Color3.fromRGB(40, 44, 54), Enum.Material.Metal)
		local cap = piece("Lamp", CFrame.new(at + Vector3.new(0, 5.1, 0)), Vector3.new(1, 0.5, 1), glow, Enum.Material.Neon)
		cap.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = glow, 18, 0.9
		light.Parent = cap
	end
	local kerb = 40
	for i = 0, kerb - 1 do
		local a = (i + 0.5) / kerb * math.pi * 2
		local at = target + Vector3.new(math.cos(a) * (radius + 1.4), -0.2, math.sin(a) * (radius + 1.4))
		local stripe = piece("Kerb", CFrame.new(at) * CFrame.Angles(0, -a, 0),
			Vector3.new(1.2, 0.5, 2 * (radius + 1.4) * math.tan(math.pi / kerb) + 0.1),
			if i % 2 == 0 then Color3.fromRGB(240, 178, 48) else Color3.fromRGB(30, 32, 38), Enum.Material.SmoothPlastic)
		stripe.CanCollide = false
	end
	return model
end

function PrivateArenas.stage(name: string, ground: Vector3, reach: number): Vector3?
	local center = floor()
	local radius = 30
	pcall(function()
		local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
		local r = landmarks and landmarks:GetAttribute("ArenaRadius")
		if type(r) == "number" then
			radius = r
		end
	end)
	-- (its floor at the Arena's height over the ground, so a fight there is
	-- one as in the Arena)
	local target = Vector3.new(ground.X, ground.Y + (if center then center.Y else 0.7), ground.Z)
	local ok, model = pcall(ringAt, name, target, radius)
	if not ok then
		warn("[PrivateArenas] stage failed:", model)
		return nil
	end
	model:SetAttribute("Center", target)
	model:SetAttribute("Stage", true)
	local glow = PrivateArenas.RingColors[name] or Color3.fromRGB(110, 220, 255)
	local stage = { Name = name, Model = model, Center = target, Fence = fenceOf(model, target, reach, glow), Owner = nil :: Player?, Holders = {} }
	model.Parent = folder()
	table.insert(stages, stage)
	return target
end

function PrivateArenas.claim(player: Player): Vector3?
	local mine = owned[player]
	if mine and mine.Parent then
		return mine:GetAttribute("Center")
	end
	-- Arena Row first, out in the open, when one's free.
	for _, stage in stages do
		if not stage.Owner and stage.Model.Parent then
			stage.Owner = player
			stage.Holders = { [player] = true }
			stage.Model:SetAttribute("Owner", player.UserId)
			fenced(stage, true)
			owned[player] = stage.Model
			player:SetAttribute("ArenaCenter", stage.Center)
			return stage.Center
		end
	end
	local center = floor()
	local source = workspace:FindFirstChild("CombatArena")
	if not center or not source then
		return nil
	end
	local model = table.remove(spares)
	if not model then
		local slot = freeSlot()
		local offset = PrivateArenas.Origin + Vector3.new((slot - 1) * PrivateArenas.Gap, 0, 0)
		local ok, built = pcall(copy, source, offset)
		if not ok then
			warn("[PrivateArenas] copy failed:", built)
			return nil
		end
		model = built
		model:SetAttribute("Slot", slot)
		model:SetAttribute("Center", center + offset)
		used[slot] = true
	end
	model:SetAttribute("Owner", player.UserId)
	model.Parent = folder()
	owned[player] = model
	player:SetAttribute("ArenaCenter", model:GetAttribute("Center"))
	return model:GetAttribute("Center")
end

function PrivateArenas.claimStage(players: { Player }, prefer: string?): Vector3?
	if #players == 0 then
		return nil
	end
	local pick = nil
	for _, stage in stages do
		if not stage.Owner and stage.Model.Parent and (not pick or stage.Name == prefer) then
			pick = stage
		end
	end
	if not pick then
		return nil
	end
	pick.Owner = players[1]
	pick.Holders = {}
	pick.Model:SetAttribute("Owner", players[1].UserId)
	fenced(pick, true)
	for _, player in players do
		PrivateArenas.release(player) -- (anything they held before)
		pick.Holders[player] = true
		owned[player] = pick.Model
		player:SetAttribute("ArenaCenter", pick.Center)
	end
	return pick.Center
end

function PrivateArenas.release(player: Player)
	player:SetAttribute("ArenaCenter", nil)
	local model = owned[player]
	owned[player] = nil
	if not model then
		return
	end
	for _, stage in stages do
		if stage.Model == model then
			stage.Holders[player] = nil
			local next_ = next(stage.Holders) :: Player?
			if next_ == nil then
				stage.Owner = nil -- (Arena Row's: stays, open again once everyone's out)
				model:SetAttribute("Owner", nil)
				fenced(stage, false)
			else
				stage.Owner = next_
				model:SetAttribute("Owner", next_.UserId)
			end
			return
		end
	end
	model:SetAttribute("Owner", nil)
	if #spares < PrivateArenas.Spare and model.Parent then
		table.insert(spares, model)
	else
		used[model:GetAttribute("Slot")] = nil
		model:Destroy()
	end
end

-- Arena Row's rings as they are now, in order: { Name, Fighters = { name } }
-- (Server.Boards: the LED screens' live board).
function PrivateArenas.rings(): { { Name: string, Fighters: { string } } }
	local list = {}
	for _, stage in stages do
		local fighters = {}
		for player in stage.Holders do
			table.insert(fighters, player.DisplayName)
		end
		table.sort(fighters)
		table.insert(list, { Name = stage.Name, Fighters = fighters })
	end
	return list
end

-- Who has one now (for tests and the DEV tools).
function PrivateArenas.of(player: Player): Model?
	return owned[player]
end

function PrivateArenas.start()
	Players.PlayerRemoving:Connect(PrivateArenas.release)
end

return PrivateArenas
