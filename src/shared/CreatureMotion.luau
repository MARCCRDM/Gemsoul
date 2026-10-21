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
	elseif kind == "Stride" then
		-- a kaiju's legs (side 1 and -1 step in turn; a four-legged one pairs them diagonally)
		return math.sin(phase + (if side > 0 then 0 else math.pi)) * 0.55 * amount, 0, 0
	elseif kind == "Arm" then
		-- a kaiju's arms: swing against the legs, and reach forward on a blow
		return math.sin(phase + (if side > 0 then math.pi else 0)) * 0.3 * amount
			+ math.sin(time * 1.4 + side) * 0.04
			+ attack * 0.9,
			0,
			0
	elseif kind == "Body" then
		-- a kaiju's trunk on its hips: it breathes, and bobs as it walks
		return math.sin(time * 2.1) * 0.015 + math.sin(phase * 2) * 0.03 * amount, 0, 0
	elseif kind == "Moss" then
		return math.sin(time * 1.6 + side) * 0.06 + amount * 0.08, 0, math.sin(phase + side) * amount * 0.08
	elseif kind == "Head" then
		-- one of a boss's heads (side tells them apart): it looks about on
		-- its own, bobs as it walks, and lunges in on a blow
		return math.sin(time * 1.3 + side * 1.7) * 0.05 + math.sin(phase * 2) * 0.04 * amount - attack * 0.24,
			math.sin(time * 0.55 + side * 2.1) * 0.22 * (1 - attack),
			math.sin(time * 0.8 + side) * 0.04
	elseif kind == "Wing" then
		-- flaps, faster on the move, and beats hard on a blow (side: which wing)
		local flap = math.sin(time * (4 + amount * 4)) * (0.22 + amount * 0.18) + attack * 0.5
		return 0, side * math.sin(time * 1.2) * 0.06, side * flap
	elseif kind == "Blade" then
		-- an extra arm's knife: twirls at rest, chops down and in on a blow
		return math.sin(time * 2.4 + side) * 0.06 - attack * 1.1, side * math.sin(time * 1.5) * 0.08, -side * attack * 0.4
	end
	return 0, 0, 0
end

-- A kaiju's fight -------------------------------------------------------------------------------
-- How its whole body moves in a fight (KaijuFighter's attributes on its
-- model), on top of its walk: a pose of
--   Pitch  its trunk rearing up (+) or leaning in (-), on its hips
--   Yaw    its trunk turning (+ to its left), Roll leaning (+ to its left)
--   Lift   its trunk up (+) or down (studs at scale 1), Push forward (+)
--   Jaw    its jaw opening (+), Arm its arms reaching forward and up (+)
--   ArmSide  the one arm a swipe uses (0: both), Tail its tail swinging
-- Each blow winds up into Wind (by its ActionAt), strikes into Hit, and
-- settles back. Yaw, Roll and Tail turn to the blow's side (ActionSide).
Motion.Strike = 0.1 -- seconds from its wind-up pose into the blow
Motion.Settle = 0.35 -- and back to rest

Motion.Fight = {
	Bulwark = {
		-- Claw Swipe: one arm drawn back, then raked across.
		Light = {
			Wind = { Yaw = 0.25, Arm = -0.5, Pitch = 0.05 },
			Hit = { Yaw = -0.35, Arm = 1.3, Pitch = -0.12, Push = 0.3 },
			OneArm = true,
		},
		-- Ground Stomp: rears up, arms high, then slams down.
		Heavy = {
			Wind = { Pitch = 0.32, Lift = 0.08, Arm = 1.8, Jaw = 0.3 },
			Hit = { Pitch = -0.22, Lift = -0.15, Arm = 0.7, Jaw = 0.5 },
		},
		-- Shoulder Ram: head down into it.
		Lunge = { Wind = { Pitch = -0.25, Push = -0.2 }, Hit = { Pitch = -0.35, Push = 0.5, Arm = 0.6 } },
		Cast = { Wind = { Pitch = 0.3, Jaw = 0.6, Arm = -0.6 }, Hit = { Pitch = -0.1, Jaw = 0.8, Arm = 0.4 } },
		-- Braced behind its forearms.
		Guard = { Pitch = -0.12, Lift = -0.12, Arm = 1.1 },
	},
	Razorback = {
		-- Bite: rears back jaws wide, then snaps forward.
		Light = {
			Wind = { Pitch = 0.12, Push = -0.25, Jaw = 0.7 },
			Hit = { Pitch = -0.22, Push = 0.55, Jaw = -0.1 },
		},
		-- Tail Lash: coils one way, then spins the tail round.
		Heavy = {
			Wind = { Yaw = 0.7, Tail = -0.6, Lift = 0.05 },
			Hit = { Yaw = -1.4, Tail = 1, Roll = 0.1 },
		},
		-- Pounce: a crouch, then a spring.
		Lunge = { Wind = { Pitch = 0.18, Lift = -0.15, Jaw = 0.5 }, Hit = { Pitch = -0.2, Lift = 0.3, Push = 0.5 } },
		Cast = { Wind = { Pitch = 0.35, Jaw = 0.8 }, Hit = { Pitch = -0.1, Jaw = 0.9 } },
		-- Low, snarling.
		Guard = { Pitch = -0.1, Lift = -0.25, Jaw = 0.25 },
	},
	Carapace = {
		-- Shell Snap: a quick bite from under the shell.
		Light = { Wind = { Pitch = 0.08, Push = -0.15, Jaw = 0.6 }, Hit = { Pitch = -0.1, Push = 0.4, Jaw = -0.1 } },
		-- Shell Slam: rears its front up, then crashes down.
		Heavy = { Wind = { Pitch = 0.38, Lift = 0.4 }, Hit = { Pitch = -0.12, Lift = -0.2, Jaw = 0.3 } },
		-- Rolling Charge: tucked low, then barrelling in.
		Lunge = { Wind = { Pitch = -0.1, Lift = -0.2 }, Hit = { Pitch = -0.2, Push = 0.6 } },
		Cast = { Wind = { Pitch = 0.25, Lift = 0.25, Jaw = 0.7 }, Hit = { Pitch = 0, Jaw = 0.8 } },
		-- Into its shell: it sinks down over its legs.
		Guard = { Lift = -0.45, Pitch = -0.05 },
	},
	Scythe = {
		-- Blade Slash: one blade drawn high, then cut down and across.
		Light = {
			Wind = { Yaw = 0.3, Arm = 1.1, Pitch = 0.12 },
			Hit = { Yaw = -0.45, Arm = -0.4, Pitch = -0.2, Push = 0.35 },
			OneArm = true,
		},
		-- Scissor Strike: rears up, both blades high, then snaps them shut.
		Heavy = {
			Wind = { Pitch = 0.35, Lift = 0.12, Arm = 1.6, Jaw = 0.4 },
			Hit = { Pitch = -0.25, Lift = -0.08, Arm = -0.5, Jaw = 0.6, Push = 0.3 },
		},
		-- Mantis Leap: a low crouch, then a spring, blades out.
		Lunge = {
			Wind = { Pitch = 0.1, Lift = -0.2, Arm = 0.8 },
			Hit = { Pitch = -0.25, Lift = 0.35, Push = 0.6, Arm = 0.2 },
		},
		Cast = { Wind = { Pitch = 0.3, Jaw = 0.7, Arm = 1.3 }, Hit = { Pitch = -0.1, Jaw = 0.8, Arm = 0.5 } },
		-- Blades crossed in front of it.
		Guard = { Pitch = 0.08, Lift = -0.1, Arm = 1.2 },
	},
}
-- (A counter swings as a quick blow; an E, aimed or round itself, is its cast.)
local ALIASES = { Punish = "Light", Bolt = "Cast", Nova = "Cast" }
local SIDED = { Yaw = true, Roll = true, Tail = true }

function Motion.rest()
	return { Pitch = 0, Yaw = 0, Roll = 0, Lift = 0, Push = 0, Jaw = 0, Arm = 0, ArmSide = 0, Tail = 0 }
end

local function add(pose, key, weight: number, side: number)
	if not key or weight == 0 then
		return
	end
	for field, value in key do
		pose[field] += value * weight * (if SIDED[field] then side else 1)
	end
end

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- A wild kaiju's day (KaijuWilds: KaijuMood, from KaijuMoodAt): head down
-- sniffing the ground, looking about, lying down, asleep (lower, curled),
-- or a roar (rearing, jaws wide); and Bound, held by a tame, struggling
-- against it. Each settles in over a moment.
Motion.Moods = {
	Sniff = function(pose, t, k)
		pose.Pitch -= 0.28 * k
		pose.Lift -= 0.06 * k
		pose.Jaw += (0.05 + math.max(0, math.sin(t * 7)) * 0.08) * k
		pose.Pitch += math.sin(t * 6) * 0.03 * k
	end,
	Look = function(pose, t, k)
		pose.Yaw += math.sin(t * 0.9) * 0.4 * k
		pose.Pitch += 0.06 * k
	end,
	Rest = function(pose, t, k)
		pose.Lift -= 0.38 * k
		pose.Pitch -= 0.05 * k
		pose.Tail += 0.15 * k
		pose.Pitch += math.sin(t * 1.1) * 0.01 * k
	end,
	Sleep = function(pose, t, k)
		pose.Lift -= 0.45 * k
		pose.Pitch -= 0.12 * k
		pose.Tail += 0.35 * k
		pose.Arm -= 0.2 * k
		pose.Lift += math.sin(t * 0.8) * 0.02 * k
	end,
	Bound = function(pose, t, k)
		-- Crouched low and straining: it twists and tugs, jaws snapping,
		-- harder as the hold goes on.
		local strain = k * (0.7 + math.min(t, 2.5) * 0.12)
		pose.Lift -= 0.22 * k
		pose.Pitch -= 0.1 * k
		pose.Yaw += (math.sin(t * 11) * 0.12 + math.sin(t * 4.3) * 0.08) * strain
		pose.Roll += math.sin(t * 13 + 1) * 0.06 * strain
		pose.Pitch += math.max(0, math.sin(t * 5.5)) * 0.14 * strain
		pose.Jaw += (0.15 + math.max(0, math.sin(t * 9)) * 0.45) * strain
		pose.Arm += math.sin(t * 7) * 0.25 * strain
		pose.Tail += math.sin(t * 10) * 0.4 * strain
	end,
	Roar = function(pose, t, _k)
		-- Rears back over a third of a second, holds it, and settles.
		local k = if t < 0.3 then t / 0.3 elseif t < 1.2 then 1 else math.max(0, 1 - (t - 1.2) / 0.4)
		pose.Pitch += 0.32 * k
		pose.Jaw += 0.9 * k
		pose.Arm += 0.5 * k
		pose.Lift += 0.08 * k
		pose.Yaw += math.sin(t * 9) * 0.04 * k
	end,
}

-- Its fight pose at `now` (server time). `a` = { Kind, Start, At, Side,
-- GuardUntil, BlockedAt, HurtAt, HurtSide, Mood, MoodAt }, its model's
-- ActionKind, ActionStart, ActionAt, ActionSide, GuardUntil, BlockedAt,
-- HurtAt, HurtSide, KaijuMood and KaijuMoodAt (its mood only out of a fight).
function Motion.fight(species: string?, a, now: number)
	local pose = Motion.rest()
	local mood = Motion.Moods[a.Mood or ""]
	if mood and a.Kind == nil and type(a.MoodAt) == "number" then
		local t = math.max(0, now - a.MoodAt)
		mood(pose, t, ease(t / 0.8))
	end
	local keys = Motion.Fight[species or ""] or Motion.Fight.Bulwark
	local side = if (a.Side or 1) < 0 then -1 else 1
	local kind, start, at = a.Kind, a.Start, a.At
	if type(kind) == "string" and type(start) == "number" and type(at) == "number" then
		local key = keys[ALIASES[kind] or kind]
		if key and key.Wind then
			-- Into the wind-up, through the blow, and back.
			local wind, hit = 0, 0
			if now >= start and now < at then
				wind = ease((now - start) / math.max(at - start, 0.01))
			elseif now >= at and now < at + Motion.Strike then
				hit = (now - at) / Motion.Strike
				wind = 1 - hit
			elseif now >= at + Motion.Strike and now < at + Motion.Strike + Motion.Settle then
				hit = 1 - ease((now - at - Motion.Strike) / Motion.Settle)
			end
			add(pose, key.Wind, wind, side)
			add(pose, key.Hit, hit, side)
			if key.OneArm then
				pose.ArmSide = side
			end
		elseif kind == "Dodge" then
			-- A hop: up and leaning into it.
			local t = (now - start) / 0.35
			if t >= 0 and t < 1 then
				local k = math.sin(t * math.pi)
				pose.Lift += 0.5 * k
				pose.Roll -= 0.45 * side * k
			end
		elseif kind == "Stagger" then
			-- Reeling: thrown back, jaw slack.
			local t = now - start
			if t >= 0 and t < 0.55 then
				local k = if t < 0.08 then t / 0.08 else 1 - (t - 0.08) / 0.47
				pose.Pitch += 0.3 * k
				pose.Roll += 0.15 * side * k
				pose.Jaw += 0.45 * k
				pose.Push -= 0.25 * k
			end
		end
	end
	-- Braced: its kind's guard, jolted as a blow lands on it.
	if type(a.GuardUntil) == "number" and a.GuardUntil > now then
		add(pose, keys.Guard, 1, 1)
		local blocked = if type(a.BlockedAt) == "number" then now - a.BlockedAt else -1
		if blocked >= 0 and blocked < 0.2 then
			pose.Push -= 0.2 * (1 - blocked / 0.2)
		end
	end
	-- A flinch as a blow gets through.
	local hurt = if type(a.HurtAt) == "number" then now - a.HurtAt else -1
	if hurt >= 0 and hurt < 0.25 then
		local k = 1 - hurt / 0.25
		pose.Pitch += 0.12 * k
		pose.Roll += 0.08 * (a.HurtSide or 1) * k
	end
	return pose
end

-- Eases `from` (a pose, or nil) toward `to` by `t`; returns it.
function Motion.blend(from, to, t: number)
	if not from then
		return table.clone(to)
	end
	for field, value in to do
		if field == "ArmSide" then
			from.ArmSide = value
		else
			from[field] += (value - from[field]) * t
		end
	end
	return from
end

-- One joint of a kaiju in a fight pose: its walk's angles with the pose
-- added. The trunk (Body) also moves (lift, push: studs at scale 1); its
-- legs keep upright as it rears or leans. Returns x, y, z, lift, push.
function Motion.apply(pose, kind: string, side: number, x: number, y: number, z: number)
	if kind == "Body" then
		return x + pose.Pitch, y + pose.Yaw, z + pose.Roll, pose.Lift, pose.Push
	elseif kind == "Stride" then
		return x - pose.Pitch, y, z, 0, 0
	elseif kind == "Jaw" then
		return x - pose.Jaw, y, z, 0, 0
	elseif kind == "Arm" then
		local share = if pose.ArmSide == 0 or side == pose.ArmSide then 1 else 0.25
		return x + pose.Arm * share, y, z, 0, 0
	elseif kind == "Tail" then
		return x, y + pose.Tail * 0.3, z, 0, 0 -- (each segment: the tail curls)
	end
	return x, y, z, 0, 0
end

return Motion
