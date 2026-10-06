-- One absolute-time choreography for server staging, local pods and helmet POV.
-- Sampling is independent of frame rate; late clients join the current phase.
local Motion = {
	Lead = 0.45,
	Spacing = 1.75,
	Landing = 0.72,
	Hatch = 0.91,
	Exit = 1.18,
	ExitDuration = 0.5,
	Ready = 2.1,
	Altitude = 82,
	SmokeAfter = 4,
	Handoff = 0.4,
}
function Motion.smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * x * (x * (x * 6 - 15) + 10)
end
function Motion.duration(count)
	return Motion.Lead + math.max(0, count - 1) * Motion.Spacing + Motion.Ready + Motion.Handoff
end
function Motion.sample(t)
	local descent = Motion.smooth(t / Motion.Landing)
	local impactAge = math.max(0, t - Motion.Landing)
	-- Starts and ends at zero: no discontinuity at contact, unlike an instant kick.
	local impact = if t >= Motion.Landing and impactAge < 0.28 then math.sin(impactAge / 0.28 * math.pi) ^ 2 else 0
	local exit = Motion.smooth((t - Motion.Exit) / Motion.ExitDuration)
	local stride = math.sin(exit * math.pi * 2) * math.sin(exit * math.pi)
	return {
		Height = Motion.Altitude * (1 - descent),
		Impact = impact,
		Step = exit * 3,
		Bob = stride * 0.035,
		Pitch = impact * 0.065 - math.sin(exit * math.pi) * 0.018,
		Hatch = Motion.smooth((t - Motion.Hatch) / 0.35),
		Draw = Motion.smooth((t - Motion.Exit - 0.08) / 0.62),
		Fov = math.sin(descent * math.pi) * 3 + impact * 1.2,
	}
end
return Motion
