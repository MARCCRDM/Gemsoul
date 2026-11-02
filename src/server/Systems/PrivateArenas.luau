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

function PrivateArenas.claim(player: Player): Vector3?
	local mine = owned[player]
	if mine and mine.Parent then
		return mine:GetAttribute("Center")
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
