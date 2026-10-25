--[[
	A body flashing as a blow lands on it (client only): a Highlight that
	fills it white-hot for a frame or two, then fades through the blow's
	colour. A handful are kept and reused, so a flurry never runs past the
	room OutlineBudget leaves for hit flashes.

	  HitFlash.flash(model, color?, strength?)  strength 1 a blow, ~1.5 a
	      heavy or a crit (brighter and a touch longer)
	  HitFlash.fill(strength, t) -> number      pure: its fill transparency
	      `t` seconds in (1 = gone)
]]
local RunService = game:GetService("RunService")

local HitFlash = {}

HitFlash.Pool = 4
HitFlash.Seconds = 0.16

local WHITE = Color3.new(1, 1, 1)

-- Fill transparency `t` seconds into a flash of `strength`: near-solid at
-- once, then fading out (a stronger one holds longer).
function HitFlash.fill(strength: number, t: number): number
	local length = HitFlash.Seconds * (0.8 + 0.4 * math.clamp(strength, 0.5, 2))
	if t < 0 or t >= length then
		return 1
	end
	local start = math.clamp(0.45 - 0.2 * (strength - 1), 0.15, 0.6)
	local p = t / length
	return start + (1 - start) * p * p
end

local slots = {}
local stepping: RBXScriptConnection? = nil

local function step()
	local now = os.clock()
	local live = false
	for _, slot in slots do
		if slot.Adornee then
			local t = now - slot.At
			local fill = HitFlash.fill(slot.Strength, t)
			if fill >= 1 or not slot.Adornee.Parent then
				slot.Highlight.Enabled = false
				slot.Highlight.Adornee = nil
				slot.Adornee = nil
			else
				live = true
				slot.Highlight.FillTransparency = fill
				slot.Highlight.OutlineTransparency = math.min(1, fill + 0.15)
				-- White-hot for the first moment, then the blow's colour.
				slot.Highlight.FillColor = WHITE:Lerp(slot.Color, math.clamp(t / 0.06, 0, 1))
			end
		end
	end
	if not live and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

local function slotFor(model: Instance)
	local free, oldest
	for _, slot in slots do
		if slot.Adornee == model then
			return slot
		end
		if not slot.Adornee then
			free = free or slot
		elseif not oldest or slot.At < oldest.At then
			oldest = slot
		end
	end
	if free then
		return free
	end
	if #slots < HitFlash.Pool then
		local highlight = Instance.new("Highlight")
		highlight.Name = "HitFlash"
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Enabled = false
		highlight.FillTransparency = 1
		highlight.OutlineColor = WHITE
		highlight.Parent = workspace
		local slot = { Highlight = highlight, At = 0, Strength = 1, Color = WHITE }
		table.insert(slots, slot)
		return slot
	end
	return oldest
end

function HitFlash.flash(model: Instance?, color: Color3?, strength: number?)
	if not model or not model.Parent then
		return
	end
	local slot = slotFor(model)
	slot.Adornee = model
	slot.At = os.clock()
	slot.Strength = strength or 1
	slot.Color = (color or WHITE):Lerp(WHITE, 0.35)
	slot.Highlight.Adornee = model
	slot.Highlight.FillColor = WHITE
	slot.Highlight.FillTransparency = HitFlash.fill(slot.Strength, 0)
	slot.Highlight.Enabled = true
	if not stepping then
		stepping = RunService.RenderStepped:Connect(step)
	end
end

return HitFlash
