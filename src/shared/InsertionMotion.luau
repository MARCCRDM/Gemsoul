-- One absolute-time choreography for server staging, local pods and helmet POV.
-- Sampling is independent of frame rate; late clients join the current phase.
local Motion = {
	Lead = 0.8,
	Spacing = 2.9,
	Landing = 1.3,
	Hatch = 1.86,
	Exit = 2.26,
	ExitDuration = 0.78,
	Ready = 3.55,
	Altitude = 82,
}
function Motion.smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * x * (x * (x * 6 - 15) + 10)
end
function Motion.duration(count)
	return Motion.Lead + math.max(0, count - 1) * Motion.Spacing + Motion.Ready + 0.65
end
function Motion.sample(t)
	local descent = Motion.smooth(t / Motion.Landing)
	local impactAge = math.max(0, t - Motion.Landing)
	-- Starts and ends at zero: no discontinuity at contact, unlike an instant kick.
	local impact = if t >= Motion.Landing then math.sin(impactAge * 18) * math.exp(-impactAge * 7) else 0
	local exit = Motion.smooth((t - Motion.Exit) / Motion.ExitDuration)
	local stride = math.sin(exit * math.pi * 2) * math.sin(exit * math.pi)
	return {
		Height = Motion.Altitude * (1 - descent),
		Impact = impact,
		Step = exit * 3,
		Bob = stride * 0.035,
		Pitch = impact * 0.045 - math.sin(exit * math.pi) * 0.018,
		Hatch = Motion.smooth((t - Motion.Hatch) / 0.58),
		Draw = Motion.smooth((t - Motion.Exit - 0.12) / 1.15),
		Fov = math.sin(descent * math.pi) * 3 + impact * 1.2,
	}
end
return Motion
