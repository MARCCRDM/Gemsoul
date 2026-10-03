--[[
	Roblox draws at most 31 Highlights on screen at once; past that, some
	silently vanish. Every gem-enchanted piece of gear carries one (up to six
	per fighter), so in a crowded fight the client keeps only the nearest
	gem outlines switched on, leaving room for the target-lock outline and
	hit flashes. Purely local: it only toggles Enabled on this client.

	  OutlineBudget.choose(entries, budget)  pure: which entries stay on,
	    nearest first; entries are { Distance }
	  OutlineBudget.start()  checks twice a second
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage.Shared.Tags)

local OutlineBudget = {}
OutlineBudget.Budget = 24 -- of Roblox's 31, leaving room for other outlines

-- The `budget` nearest entries: { [entry] = true }.
function OutlineBudget.choose(entries, budget: number)
	local sorted = table.clone(entries)
	table.sort(sorted, function(a, b)
		return a.Distance < b.Distance
	end)
	local on = {}
	for i = 1, math.min(budget, #sorted) do
		on[sorted[i]] = true
	end
	return on
end

-- Where an outline is: the first part of the gear it outlines.
local function positionOf(highlight: Instance): Vector3?
	local target = highlight:IsA("Highlight") and (highlight.Adornee or highlight.Parent)
	if not target then
		return nil
	end
	if target:IsA("BasePart") then
		return target.Position
	end
	local part = target:FindFirstChildWhichIsA("BasePart", true)
	return if part then part.Position else nil
end

local started = false
function OutlineBudget.start()
	if started then
		return
	end
	started = true
	local nextCheck = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextCheck then
			return
		end
		nextCheck = now + 0.5
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local entries = {}
		for _, highlight in CollectionService:GetTagged(Tags.GemOutline) do
			local at = highlight:IsDescendantOf(workspace) and positionOf(highlight)
			if at then
				table.insert(entries, { Highlight = highlight, Distance = (at - eye).Magnitude })
			end
		end
		if #entries <= OutlineBudget.Budget then
			for _, entry in entries do
				entry.Highlight.Enabled = true
			end
			return
		end
		local on = OutlineBudget.choose(entries, OutlineBudget.Budget)
		for _, entry in entries do
			entry.Highlight.Enabled = on[entry] == true
		end
	end)
end

return OutlineBudget
