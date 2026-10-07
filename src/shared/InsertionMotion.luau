-- One absolute-time choreography for server staging, local pods and helmet POV.
-- Sampling is independent of frame rate; late clients join the current phase.
local Motion = {
	Lead = 0.2,
	Spacing = 0.05,
	ExitSpacing = 0.05,
	ExitDistance = 3,
	Landing = 0.95,
	Hatch = 1.04,
	HatchDuration = 0.2,
	ShellBurst = 1.3,
	Exit = 1.38,
	ExitDuration = 0.32,
	Ready = 2,
	Altitude = 125,
	Approach = 22,
	SmokeAfter = 6,
	Handoff = 0.35,
}
function Motion.smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * x * (x * (x * 6 - 15) + 10)
end
function Motion.releaseDelay(slot, count)
	return math.max(0, count - slot) * Motion.Spacing + math.max(0, slot - 1) * Motion.ExitSpacing
end
function Motion.duration(count)
	local last = math.max(1, count)
	return Motion.Lead + (last - 1) * Motion.Spacing + Motion.releaseDelay(last, last) + Motion.Ready + Motion.Handoff
end
-- Cosmetic shell rupture: one outward throw, followed by gravity and a fade.
function Motion.blast(t, releaseDelay)
	t -= releaseDelay or 0
	local age = math.max(0, t - Motion.ShellBurst)
	local travel = 1 - math.exp(-age * 5)
	return {
		Travel = travel,
		Lift = 10 * age - 14 * age * age,
		Spin = math.min(age, 1.6),
		Fade = Motion.smooth((age - 0.65) / 0.95),
		Flash = if t >= Motion.ShellBurst then math.exp(-age * 15) else 0,
	}
end
function Motion.smokeSpread(t)
	return 2 + 28 * Motion.smooth((t - Motion.Landing) / 1.5)
end
function Motion.audio(t)
	local p = math.clamp(t / Motion.Landing, 0, 1)
	local air = if t >= 0 and t < Motion.Landing
		then Motion.smooth(t / 0.2) * (1 - Motion.smooth((t - Motion.Landing + 0.12) / 0.12))
		else 0
	local rumble = if t < 0
		then 0
		elseif t < Motion.Landing then Motion.smooth(t / 0.25) * (0.35 + 0.65 * p)
		else math.exp(-(t - Motion.Landing) * 9)
	return { Air = air, Pitch = 0.65 + p * 1.1, Rumble = if t < Motion.Landing + 0.65 then rumble else 0 }
end
function Motion.sample(t, releaseDelay)
	local released = t - (releaseDelay or 0)
	local descent = Motion.smooth(t / Motion.Landing)
	local impactAge = math.max(0, t - Motion.Landing)
	-- Starts and ends at zero: no discontinuity at contact, unlike an instant kick.
	local impact = if t >= Motion.Landing and impactAge < 0.28 then math.sin(impactAge / 0.28 * math.pi) ^ 2 else 0
	local exit = Motion.smooth((released - Motion.Exit) / Motion.ExitDuration)
	local stride = math.sin(exit * math.pi * 2) * math.sin(exit * math.pi)
	return {
		Height = Motion.Altitude * (1 - descent),
		Approach = Motion.Approach * (1 - descent),
		Impact = impact,
		Step = exit * Motion.ExitDistance,
		Bob = stride * 0.035,
		Pitch = -math.sin(descent * math.pi) * 0.18 + impact * 0.065 - math.sin(exit * math.pi) * 0.018,
		Hatch = Motion.smooth((t - Motion.Hatch) / Motion.HatchDuration),
		Draw = Motion.smooth((released - Motion.Exit - 0.04) / 0.34),
		Fov = math.sin(descent * math.pi) * 3 + impact * 1.2,
	}
end
return Motion
