--[[
	The Kaiju Kennel's residents (Shared.KaijuKennel): today's kaiju in the
	pen on the Shelter's stage, wandering their wedges of it, stopping to
	sniff the ground, look about, lie down, nap or roar. Drawn by each
	player's own client from the server's clock (everyone sees the same),
	posed by CreatureAnimation like any kaiju (it walks them at their
	PacedSpeed: they're moved, not pushed, so they have no velocity of
	their own).

	None of them collides, casts about for clicks or can be hit; they're
	only there while you're in the Outpost and near the Shelter, and a new
	day brings new ones.

	  KennelLife.mount(at)   the Shelter's frame (once)
	  KennelLife.show(on)    shows or hides them
	  KennelLife.step(dt)    moves them (30 times a second at most)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Kennel = require(Shared:WaitForChild("KaijuKennel"))
local KaijuModels = require(Shared:WaitForChild("KaijuModels"))

local KennelLife = {}
KennelLife.Reach = 260 -- studs from the pen: past this they're put away

type Resident = { Model: Model, Root: BasePart, Lift: number, Mood: string?, MoodAt: number? }

local at: CFrame? = nil
local folder: Folder? = nil
local residents: { Resident } = {}
local shownDay: number? = nil
local wanted = false
local clock = 0

-- One resident: its kind's model at the kennel's size, a Humanoid only so
-- CreatureAnimation takes it for a kaiju (it never runs: the root is
-- anchored and moved), nothing on it touchable.
local function resident(entry): Resident
	local model = KaijuModels.build(entry.Species, entry.Element)
	KaijuModels.scale(model, Kennel.Scale)
	model.Name = "Kennel" .. entry.Species
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		end
	end
	local root = model.PrimaryPart :: BasePart
	root.Anchored = true
	local humanoid = Instance.new("Humanoid")
	humanoid.EvaluateStateMachine = false
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model
	model:SetAttribute("PacedSpeed", 0)
	model:SetAttribute("Kennel", true)
	return {
		Model = model,
		Root = root,
		-- (its root's height over its feet: hips and any hover)
		Lift = (model:GetAttribute("KaijuHipHeight") or 1) + root.Size.Y / 2,
	}
end

local function clear()
	for _, r in residents do
		r.Model:Destroy()
	end
	table.clear(residents)
end

-- Today's residents, built (again, when the day turns).
local function stock(now: number)
	local day = Kennel.day(now)
	if day == shownDay then
		return
	end
	shownDay = day
	clear()
	for _, entry in Kennel.residents(day) do
		local r = resident(entry)
		r.Model.Parent = folder
		table.insert(residents, r)
	end
end

function KennelLife.pose(now: number)
	if not at then
		return
	end
	local parts, cframes = {}, {}
	for i, r in residents do
		local s = Kennel.state(i, #residents, now)
		table.insert(parts, r.Root)
		table.insert(cframes, at * CFrame.new(s.Position + Vector3.new(0, r.Lift, 0)) * CFrame.Angles(0, s.Yaw, 0))
		if r.Model:GetAttribute("PacedSpeed") ~= s.Speed then
			r.Model:SetAttribute("PacedSpeed", s.Speed)
		end
		if s.Mood ~= r.Mood or s.MoodAt ~= r.MoodAt then
			r.Mood, r.MoodAt = s.Mood, s.MoodAt
			r.Model:SetAttribute("KaijuMood", s.Mood)
			r.Model:SetAttribute("KaijuMoodAt", s.MoodAt)
		end
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function KennelLife.mount(frame: CFrame)
	if at then
		return
	end
	at = frame
	local made = Instance.new("Folder")
	made.Name = "KaijuKennel" -- (CreatureAnimation looks in here too)
	folder = made
end

local function near(): boolean
	local camera = workspace.CurrentCamera
	if not (at and camera) then
		return false
	end
	local pen = at * CFrame.new(Kennel.Pen.Middle)
	return (camera.CFrame.Position - pen.Position).Magnitude < KennelLife.Reach
end

function KennelLife.show(on: boolean)
	wanted = on
	if not folder then
		return
	end
	local parent = if on and near() then workspace else nil
	if folder.Parent ~= parent then
		folder.Parent = parent
	end
end

function KennelLife.step(dt: number)
	if not (folder and wanted) then
		return
	end
	clock += dt
	if clock < 1 / 30 then
		return
	end
	clock = 0
	KennelLife.show(wanted)
	if folder.Parent then
		local now = workspace:GetServerTimeNow()
		stock(now)
		KennelLife.pose(now)
	end
end

return KennelLife
