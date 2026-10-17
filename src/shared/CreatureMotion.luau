-- Cosmetic motion only. Server action timestamps keep every viewer's jaw
-- recoil and tail follow-through in time with the same combat release.
local Motion = {}

function Motion.angles(kind: string, time: number, phase: number, amount: number, side: number, actionAt: number?)
	local since = if actionAt then time - actionAt else -1
	local attack = if since >= 0 and since < 0.45 then math.sin(since / 0.45 * math.pi) else 0
	if kind == "Propeller" then
		return 0, 0, (time * 24 * side) % (2 * math.pi)
	elseif kind == "Tail" then
		return 0, math.sin(phase + 0.6) * 0.27 * amount + math.sin(time * 1.8) * 0.045 + attack * 0.12, 0
	elseif kind == "Jaw" then
		return -0.035 * (1 + math.sin(time * 2.2)) - attack * 0.24, 0, 0
	elseif kind == "ThirdFoot" then
		return math.sin(phase + math.pi * 0.66) * 0.32 * amount, 0, 0
	elseif kind == "Moss" then
		return math.sin(time * 1.6 + side) * 0.06 + amount * 0.08, 0, math.sin(phase + side) * amount * 0.08
	end
	return 0, 0, 0
end

return Motion
