--[[
	Private arenas: a copy of the Arena (workspace.CombatArena) of one's own
	for every Training session (a new miner's first fight and intro rounds,
	a practice bout), far from everyone else's, so nobody walks into another
	player's fight, sees it, or hears it. Duels, PvP and raids keep the
	shared Arena.

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
	  PrivateArenas.release(player)             their copy, back to the spares
	  PrivateArenas.stage(name, ground, reach)  a copy built for good at
	                                            `ground` (Arena Row in the
	                                            Outpost: Shared.Outpost.
	                                            Settlement.Stages), out in the
	                                            open to watch: claimed first,
	                                            fenced off while a fight's on
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
-- Arena Row's copies: { Model, Center, Fence, Owner }, in the order they're taken.
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

-- A fence round a stage's floor, `reach` out: nobody walks into a fight
-- (or out of one); open between fights.
local function fenceOf(model: Model, center: Vector3, reach: number): Folder
	local fence = Instance.new("Folder")
	fence.Name = "StageFence"
	local segments = 24
	for i = 0, segments - 1 do
		local a = (i + 0.5) / segments * math.pi * 2
		local p = Instance.new("Part")
		p.Name = "Fence"
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Transparency = 1
		p.Size = Vector3.new(2 * reach * math.tan(math.pi / segments) + 1, 26, 1)
		p.CFrame = CFrame.new(center + Vector3.new(math.cos(a) * reach, 12, math.sin(a) * reach))
			* CFrame.Angles(0, -a + math.pi / 2, 0)
		p.Parent = fence
	end
	fence.Parent = model
	return fence
end
local function fenced(stage, on: boolean)
	for _, p in stage.Fence:GetChildren() do
		(p :: BasePart).CanCollide = on
	end
end

function PrivateArenas.stage(name: string, ground: Vector3, reach: number): Vector3?
	local center = floor()
	local source = workspace:FindFirstChild("CombatArena")
	if not center or not source then
		return nil
	end
	-- (its floor at the Arena's height over its own ground)
	local target = Vector3.new(ground.X, ground.Y + center.Y, ground.Z)
	local ok, model = pcall(copy, source, target - center)
	if not ok then
		warn("[PrivateArenas] stage failed:", model)
		return nil
	end
	model.Name = name
	model:SetAttribute("Center", target)
	model:SetAttribute("Stage", true)
	local stage = { Model = model, Center = target, Fence = fenceOf(model, target, reach), Owner = nil :: Player? }
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

function PrivateArenas.release(player: Player)
	player:SetAttribute("ArenaCenter", nil)
	local model = owned[player]
	owned[player] = nil
	if not model then
		return
	end
	model:SetAttribute("Owner", nil)
	for _, stage in stages do
		if stage.Model == model then
			stage.Owner = nil -- (Arena Row's: stays, open again)
			fenced(stage, false)
			return
		end
	end
	if #spares < PrivateArenas.Spare and model.Parent then
		table.insert(spares, model)
	else
		used[model:GetAttribute("Slot")] = nil
		model:Destroy()
	end
end

-- Who has one now (for tests and the DEV tools).
function PrivateArenas.of(player: Player): Model?
	return owned[player]
end

function PrivateArenas.start()
	Players.PlayerRemoving:Connect(PrivateArenas.release)
end

return PrivateArenas
