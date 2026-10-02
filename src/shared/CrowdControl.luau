--[[
	Crowd control and debuff rules from the PvP balance framework. Pure logic
	with no services, shared by the server (which applies them) and tests.

	Diminishing returns (PvP): within 10 seconds of the last landed CC,
	each new one lasts 100% / 50% / 25% / 0% (immune). 10 seconds without a
	landed CC resets it. PvP CC never lasts longer than 0.5 seconds.

	Anti-heal: Thermal Grievous Wounds 30%, Corrosive Mortal Strike 20%,
	together capped at 50%. Each lasts 4 seconds and refreshes on a new
	application; durations don't add up.

	Debuffs (PvP): capped at 30%, and the same debuff from several sources
	doesn't stack: the strongest one applies.
]]
local CrowdControl = {}

CrowdControl.Window = 10
CrowdControl.Steps = { 1, 0.5, 0.25, 0 }
CrowdControl.MaxPvPSeconds = 0.5
CrowdControl.HealCuts = { GrievousWounds = 0.30, MortalStrike = 0.20 }
CrowdControl.HealCutCap = 0.5
CrowdControl.HealCutSeconds = 4
CrowdControl.DebuffCap = 0.30

export type Tracker = {
	Count: number, -- CCs landed in the current window
	Last: number, -- when the last one landed
	HealCuts: { [string]: number }, -- kind -> expires at
	Debuffs: { [string]: { Amount: number, Until: number } },
}

function CrowdControl.new(): Tracker
	return { Count = 0, Last = -math.huge, HealCuts = {}, Debuffs = {} }
end

-- How long a stun/freeze/root really lasts. PvE is unchanged; PvP is capped
-- and diminished. Only a CC that lands (more than 0s) extends the window.
function CrowdControl.ApplyCC(tracker: Tracker, seconds: number, now: number, pvp: boolean?): number
	if not pvp then
		return seconds
	end
	if now - tracker.Last >= CrowdControl.Window then
		tracker.Count = 0
	end
	local step = CrowdControl.Steps[tracker.Count + 1] or 0
	local duration = math.min(seconds, CrowdControl.MaxPvPSeconds) * step
	if duration > 0 then
		tracker.Count += 1
		tracker.Last = now
	end
	return duration
end

function CrowdControl.applyHealCut(tracker: Tracker, kind: string, now: number)
	if CrowdControl.HealCuts[kind] then
		tracker.HealCuts[kind] = now + CrowdControl.HealCutSeconds
	end
end

-- Multiply incoming healing by this.
function CrowdControl.healingMultiplier(tracker: Tracker, now: number): number
	local total = 0
	for kind, expires in tracker.HealCuts do
		if now < expires then
			total += CrowdControl.HealCuts[kind] or 0
		end
	end
	return 1 - math.min(CrowdControl.HealCutCap, total)
end

-- Applies a debuff (slow, shred, vulnerability) and returns its strength now.
function CrowdControl.applyDebuff(
	tracker: Tracker,
	kind: string,
	amount: number,
	seconds: number,
	now: number,
	pvp: boolean?
): number
	local current = tracker.Debuffs[kind]
	local active = current and now < current.Until
	if pvp then
		amount = math.min(amount, CrowdControl.DebuffCap)
		amount = if active then math.max(current.Amount, amount) else amount
	elseif active then
		amount += current.Amount
	end
	tracker.Debuffs[kind] = {
		Amount = amount,
		Until = math.max(if active then current.Until else 0, now + seconds),
	}
	return amount
end

function CrowdControl.debuff(tracker: Tracker, kind: string, now: number): number
	local current = tracker.Debuffs[kind]
	return if current and now < current.Until then current.Amount else 0
end

-- Removes the longest-lasting debuff or healing cut. Returns its name, if any.
function CrowdControl.cleanse(tracker: Tracker, now: number): string?
	local worst, worstUntil, isCut = nil, now, false
	for kind, debuff in tracker.Debuffs do
		if debuff.Until > worstUntil then
			worst, worstUntil, isCut = kind, debuff.Until, false
		end
	end
	for kind, expires in tracker.HealCuts do
		if expires > worstUntil then
			worst, worstUntil, isCut = kind, expires, true
		end
	end
	if worst then
		if isCut then
			tracker.HealCuts[worst] = nil
		else
			tracker.Debuffs[worst] = nil
		end
	end
	return worst
end

return CrowdControl
