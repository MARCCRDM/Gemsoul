--[[
	Body language for the Arena rival. The server plays its walk, run and idle
	animations and, every frame, this layers the fighting on top by bending
	its joints (Motor6D C0, or an AnimationConstraint's attachment) from what
	the rival is doing. Done on the server, so it replicates to every client:

	  ActionKind   Slash, Heavy, Bolt, Nova, Buff, Dodge or Stagger
	  ActionStart  server time the wind-up began
	  ActionAt     server time the blow lands (or the cast releases)
	  ActionSide   1 or -1: which way a slash or a dodge goes
	  GuardUntil   server time its guard drops
	  HurtAt       server time it was hit (a flinch), HurtSide which way
	  BlockedAt    server time a blow landed on its shield (a jolt)

	A slash winds the arm back and whips it across; a heavy goes overhead with
	both hands and slams down; a bolt gathers and thrusts the palm forward; a
	blast raises both arms and drives them into the ground; a buff throws the
	arms wide; a guard crosses the forearms in front of the face; a dodge
	tucks and leans; a stagger rocks it back.
]]
local RivalPose = {}

-- Joint -> the part that holds it (R15).
local JOINTS = {
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	LeftShoulder = "LeftUpperArm",
	RightElbow = "RightLowerArm",
	LeftElbow = "LeftLowerArm",
	RightHip = "RightUpperLeg",
	LeftHip = "LeftUpperLeg",
	RightKnee = "RightLowerLeg",
	LeftKnee = "LeftLowerLeg",
}
local JOINT_COUNT = 10
local FOLLOW = 0.32 -- how long a strike's follow-through holds, seconds

-- Angles are radians about the joint's X (positive swings a limb forward and
-- up, or leans the torso back), Y (twists left) and Z (positive raises the
-- right arm outward; negative the left).
-- Fighting stance: shield arm forward, sword held out, knees soft.
local READY = {
	RightShoulder = { 0.45, 0, 0.12 },
	RightElbow = { 0.85, 0, 0 },
	LeftShoulder = { 0.75, 0, 0.18 },
	LeftElbow = { 1.0, 0, 0 },
	Waist = { -0.05, -0.12, 0 },
	RightHip = { 0.12, 0, 0 },
	LeftHip = { 0.12, 0, 0 },
	RightKnee = { -0.18, 0, 0 },
	LeftKnee = { -0.18, 0, 0 },
}

local function lerp(a, b, t: number)
	local out = {}
	for joint, angles in a do
		local to = b[joint] or { 0, 0, 0 }
		out[joint] = {
			angles[1] + (to[1] - angles[1]) * t,
			angles[2] + (to[2] - angles[2]) * t,
			angles[3] + (to[3] - angles[3]) * t,
		}
	end
	for joint, angles in b do
		if not out[joint] then
			out[joint] = { angles[1] * t, angles[2] * t, angles[3] * t }
		end
	end
	return out
end

-- Wind-up and strike poses for each action; `s` mirrors a slash or dodge.
local function frames(kind: string, s: number)
	if kind == "Mine" then
		return {
			Waist = { 0.15, -0.2, 0 },
			RightShoulder = { 2.7, 0, 0.2 },
			RightElbow = { 1, 0, 0 },
			LeftShoulder = {
				1.1,
				0,
				-0.3,
			},
		}, {
			Waist = { -0.35, 0.15, 0 },
			RightShoulder = { 0.6, 0, -0.2 },
			RightElbow = { 0.1, 0, 0 },
			LeftShoulder = {
				0.5,
				0,
				-0.3,
			},
		}
	elseif kind == "Feed" then
		return {
			Waist = { -0.2, 0, 0 },
			Neck = { 0.1, 0, 0 },
			RightShoulder = { 0.5, 0, 0.2 },
			LeftShoulder = {
				0.5,
				0,
				-0.2,
			},
		}, {
			Waist = { -0.55, 0, 0 },
			Neck = { -0.35, 0, 0 },
			RightShoulder = { 0.9, 0, 0.2 },
			LeftShoulder = {
				0.9,
				0,
				-0.2,
			},
		}
	elseif kind == "Drill" then
		return {
			Waist = { 0.12, -0.55, 0 },
			RightShoulder = { 1.2, -0.3, 0.65 },
			RightElbow = { 1.65, 0, 0 },
			LeftShoulder = { 0.8, 0, -0.3 },
			LeftElbow = { 1.2, 0, 0 },
		}, {
			Waist = { -0.18, 0.35, 0 },
			RightShoulder = { 1.65, 0.12, -0.08 },
			RightElbow = { 0.02, 0, 0 },
			LeftShoulder = { 0.5, 0, -0.5 },
			LeftElbow = { 0.8, 0, 0 },
		}
	elseif kind == "Sweep" then
		return {
			Waist = { 0.05, -0.8, 0.08 },
			RightShoulder = { 1.7, -0.4, 1.05 },
			RightElbow = { 0.7, 0, 0 },
			LeftShoulder = { 0.9, 0, -0.5 },
			LeftElbow = { 1.1, 0, 0 },
		}, {
			Waist = { -0.1, 0.8, -0.08 },
			RightShoulder = { 1.4, 0.4, -1.0 },
			RightElbow = { 0.15, 0, 0 },
			LeftShoulder = { 0.6, 0, -0.75 },
			LeftElbow = { 0.6, 0, 0 },
		}
	elseif kind == "Erupt" then
		return {
			Waist = { 0.3, 0, 0 },
			RightShoulder = { 2.8, 0, 0.5 },
			LeftShoulder = { 2.8, 0, -0.5 },
			RightElbow = { 1.1, 0, 0 },
			LeftElbow = { 1.1, 0, 0 },
			RightKnee = { -0.25, 0, 0 },
			LeftKnee = { -0.25, 0, 0 },
		}, {
			Waist = { -0.5, 0, 0 },
			RightShoulder = { 0.3, 0, 0.4 },
			LeftShoulder = { 0.3, 0, -0.4 },
			RightElbow = { 0.1, 0, 0 },
			LeftElbow = { 0.1, 0, 0 },
			RightHip = { 0.55, 0, 0 },
			LeftHip = { 0.55, 0, 0 },
			RightKnee = { -0.85, 0, 0 },
			LeftKnee = { -0.85, 0, 0 },
		}
	elseif kind == "Cross" then
		return {
			Waist = { 0.18, 0, 0 },
			RightShoulder = { 1.3, 0.5, -0.65 },
			LeftShoulder = { 1.3, -0.5, 0.65 },
			RightElbow = { 1.45, 0, 0 },
			LeftElbow = { 1.45, 0, 0 },
		}, {
			Waist = { -0.2, 0, 0 },
			RightShoulder = { 1.7, -0.3, 0.9 },
			LeftShoulder = { 1.7, 0.3, -0.9 },
			RightElbow = { 0.15, 0, 0 },
			LeftElbow = { 0.15, 0, 0 },
		}
	elseif kind == "Slash" then
		return {
			Waist = { 0.08, -0.48 * s, -0.06 * s },
			Neck = { -0.04, 0.18 * s, 0 },
			RightShoulder = { 1.9, -0.35 * s, 0.85 * s },
			RightElbow = { 0.9, 0, 0 },
			LeftShoulder = { 0.6, 0, -0.3 },
			LeftElbow = { 0.9, 0, 0 },
		}, {
			Waist = { -0.18, 0.58 * s, 0.08 * s },
			Neck = { 0.04, -0.18 * s, 0 },
			RightShoulder = { 0.95, 0.45 * s, -0.95 * s },
			RightElbow = { 0.15, 0, 0 },
			LeftShoulder = { 0.3, 0, -0.4 },
			LeftElbow = { 0.6, 0, 0 },
		}
	elseif kind == "Heavy" then
		return {
			Waist = { 0.3, -0.2, 0 },
			Neck = { 0.15, 0, 0 },
			RightShoulder = { 3.0, 0, 0.2 },
			LeftShoulder = { 3.0, 0, -0.2 },
			RightElbow = { 0.9, 0, 0 },
			LeftElbow = { 0.9, 0, 0 },
		}, {
			Waist = { -0.55, 0.1, 0 },
			Neck = { -0.2, 0, 0 },
			RightShoulder = { 0.7, 0, -0.15 },
			LeftShoulder = { 0.7, 0, 0.15 },
			RightElbow = { 0.1, 0, 0 },
			LeftElbow = { 0.1, 0, 0 },
			RightHip = { 0.5, 0, 0 },
			LeftHip = { -0.2, 0, 0 },
			RightKnee = { -0.6, 0, 0 },
			LeftKnee = { -0.3, 0, 0 },
		}
	elseif kind == "Bolt" then
		return {
			Waist = { 0, -0.4, 0 },
			RightShoulder = { 1.0, 0, 0.5 },
			RightElbow = { 1.5, 0, 0 },
			LeftShoulder = { 1.1, 0, -0.3 },
			LeftElbow = { 1.2, 0, 0 },
		}, {
			Waist = { -0.1, 0.25, 0 },
			RightShoulder = { 1.65, 0, -0.1 },
			RightElbow = { 0.05, 0, 0 },
			LeftShoulder = { 0.4, 0, -0.4 },
			LeftElbow = { 0.5, 0, 0 },
		}
	elseif kind == "Nova" then
		return {
			Waist = { 0.25, 0, 0 },
			Neck = { 0.35, 0, 0 },
			RightShoulder = { 2.7, 0, 0.6 },
			LeftShoulder = { 2.7, 0, -0.6 },
			RightElbow = { 0.3, 0, 0 },
			LeftElbow = { 0.3, 0, 0 },
		}, {
			Waist = { -0.6, 0, 0 },
			Neck = { -0.25, 0, 0 },
			RightShoulder = { 0.5, 0, 0.25 },
			LeftShoulder = { 0.5, 0, -0.25 },
			RightHip = { 0.7, 0, 0.1 },
			LeftHip = { 0.7, 0, -0.1 },
			RightKnee = { -1.0, 0, 0 },
			LeftKnee = { -1.0, 0, 0 },
		}
	elseif kind == "Buff" then
		return {
			RightShoulder = { 0.6, 0, 0.3 },
			LeftShoulder = { 0.6, 0, -0.3 },
			RightElbow = { 1.4, 0, 0 },
			LeftElbow = { 1.4, 0, 0 },
			Waist = { -0.2, 0, 0 },
		}, {
			-- Both hands raised in front, channelling.
			Waist = { 0.12, 0, 0 },
			Neck = { 0.2, 0, 0 },
			RightShoulder = { 1.9, 0, 0.45 },
			LeftShoulder = { 1.9, 0, -0.45 },
			RightElbow = { 0.6, 0, 0 },
			LeftElbow = { 0.6, 0, 0 },
		}
	elseif kind == "Dodge" then
		local tuck = {
			Waist = { -0.5, 0, 0.35 * s },
			Neck = { -0.2, 0, 0 },
			RightShoulder = { 1.0, 0, -0.2 },
			LeftShoulder = { 1.0, 0, 0.2 },
			RightElbow = { 1.3, 0, 0 },
			LeftElbow = { 1.3, 0, 0 },
			RightHip = { 1.0, 0, 0 },
			LeftHip = { 1.0, 0, 0 },
			RightKnee = { -1.3, 0, 0 },
			LeftKnee = { -1.3, 0, 0 },
		}
		return tuck, tuck
	elseif kind == "Stagger" then
		local reel = {
			Waist = { 0.45, 0.2, 0 },
			Neck = { 0.4, 0, 0 },
			RightShoulder = { 0.4, 0, 0.9 },
			LeftShoulder = { 0.4, 0, -0.9 },
			RightKnee = { -0.4, 0, 0 },
			LeftKnee = { -0.4, 0, 0 },
		}
		return reel, reel
	end
	return nil, nil
end

-- Guard: the shield arm raised square in front of the chest and face, the
-- weapon lowered beside the hip, crouched behind the shield.
local GUARD = {
	Waist = { -0.18, -0.3, 0 },
	Neck = { -0.1, 0.15, 0 },
	LeftShoulder = { 1.4, -0.25, 0.7 },
	LeftElbow = { 1.4, 0, 0 },
	RightShoulder = { 0.12, 0.12, -0.12 },
	RightElbow = { 0.4, 0, 0 },
	RightHip = { 0.35, 0, 0 },
	LeftHip = { 0.2, 0, 0 },
	RightKnee = { -0.5, 0, 0 },
	LeftKnee = { -0.35, 0, 0 },
}

-- Sahur uses the same action frames and timeline as a Warrior. With no shield,
-- brace the bat across the chest and raise the free hand to protect the face.
local BAT_GUARD = table.clone(GUARD)
BAT_GUARD.RightShoulder = { 1.35, 0, -0.55 }
BAT_GUARD.RightElbow = { 1.15, 0, 0 }
BAT_GUARD.LeftShoulder = { 1.2, 0, 0.3 }
BAT_GUARD.LeftElbow = { 1.45, 0, 0 }
-- Both-hand guards share the same raise/recoil/recovery path in every world view.
local WEAPON_GUARDS = {
	TwinBlades = {
		RightShoulder = { 1.3, 0, -0.65 },
		RightElbow = { 1.3, 0, 0 },
		LeftShoulder = { 1.3, 0, 0.65 },
		LeftElbow = {
			1.3,
			0,
			0,
		},
	},
	Lance = {
		RightShoulder = { 1.1, 0, -0.55 },
		RightElbow = { 1.1, 0, 0 },
		LeftShoulder = { 1.45, 0, 0.35 },
		LeftElbow = {
			0.85,
			0,
			0,
		},
	},
	Greataxe = {
		RightShoulder = { 1.35, 0, -0.7 },
		RightElbow = { 1.05, 0, 0 },
		LeftShoulder = { 1.45, 0, 0.5 },
		LeftElbow = {
			1.1,
			0,
			0,
		},
	},
	Warhammer = {
		RightShoulder = { 1.25, 0, -0.6 },
		RightElbow = { 1.2, 0, 0 },
		LeftShoulder = { 1.4, 0, 0.45 },
		LeftElbow = {
			1.1,
			0,
			0,
		},
	},
}
for _, guard in WEAPON_GUARDS do
	for joint, angles in GUARD do
		if not guard[joint] then
			guard[joint] = angles
		end
	end
end

-- Smoothstep: slow in, slow out.
local function ease(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- `layer` added on top of `pose` at weight `w` (hit flinches, shield jolts).
local function add(pose, layer, w: number)
	local out = table.clone(pose)
	for joint, angles in layer do
		local from = out[joint] or { 0, 0, 0 }
		out[joint] = { from[1] + angles[1] * w, from[2] + angles[2] * w, from[3] + angles[3] * w }
	end
	return out
end

-- Timing of a blow after its wind-up: the snap through (overshooting the
-- strike pose a little), the follow-through settling back onto it, then an
-- eased recovery to the stance.
local SNAP, OVERSHOOT, RECOVER = 0.07, 0.15, 0.3

-- Hit reactions, layered over whatever the body is doing:
--   HurtAt     server time it was hit: the torso snaps back, head jerks
--   HurtSide   1 or -1: which way the hit twists it
--   BlockedAt  server time a blow landed on its shield: the shield arm
--              is knocked back and the body braces
local HURT_TIME, BLOCK_TIME = 0.32, 0.22
local FLINCH = {
	Waist = { 0.28, 0.18, 0 },
	Neck = { 0.32, 0, 0 },
	RightShoulder = { -0.25, 0, 0.25 },
	LeftShoulder = { -0.25, 0, -0.25 },
	RightKnee = { -0.15, 0, 0 },
	LeftKnee = { -0.15, 0, 0 },
}
local JOLT = {
	LeftShoulder = { -0.35, 0, 0.15 },
	LeftElbow = { 0.35, 0, 0 },
	Waist = { 0.15, 0, 0 },
	RightKnee = { -0.2, 0, 0 },
	LeftKnee = { -0.2, 0, 0 },
}
local BAT_JOLT = table.clone(JOLT)
BAT_JOLT.RightShoulder = { -0.35, 0, -0.15 }
BAT_JOLT.RightElbow = { 0.25, 0, 0 }

-- A reaction's weight `d` seconds after it lands: up fast, then fades.
local function impulse(d: number, length: number): number
	if d < 0 or d >= length then
		return 0
	end
	if d < 0.05 then
		return d / 0.05
	end
	return (1 - (d - 0.05) / (length - 0.05)) ^ 2
end

-- Breathing and a slight weight shift in the fighting stance, so it never
-- stands frozen between blows.
local function breathe(pose, t: number)
	local b = math.sin(t * 2.4)
	local shift = math.sin(t * 0.9)
	return add(pose, {
		Waist = { 0.03 * b, 0.05 * shift, 0 },
		Neck = { -0.02 * b, -0.04 * shift, 0 },
		RightShoulder = { 0.04 * b, 0, 0 },
		LeftShoulder = { 0.04 * b, 0, 0 },
		RightKnee = { -0.04 * (1 + b), 0, 0 },
		LeftKnee = { -0.04 * (1 + b), 0, 0 },
	}, 1)
end

-- Cast silhouettes: coil through the hips, brace, then release with the whole body.
-- Presentation only: ActionAt remains the server's authoritative release time.
local CAST_STYLE = {
	Bolt = { Twist = -0.5, Lean = -0.2, Snap = 0.07, Follow = 0.24 },
	Drill = { Twist = -0.65, Lean = -0.28, Snap = 0.075, Follow = 0.26 },
	Sweep = { Twist = -0.95, Lean = -0.16, Snap = 0.11, Follow = 0.3 },
	Nova = { Twist = 0, Lean = -0.65, Snap = 0.1, Follow = 0.32 },
	Erupt = { Twist = 0, Lean = -0.6, Snap = 0.09, Follow = 0.32 },
	Cross = { Twist = -0.12, Lean = -0.28, Snap = 0.1, Follow = 0.28 },
	Buff = { Twist = 0, Lean = 0.16, Snap = 0.12, Follow = 0.38 },
}
local function stageCast(kind, windup, strike)
	local style = CAST_STYLE[kind]
	if not style then
		return
	end
	windup.Waist = { if kind == "Nova" or kind == "Erupt" then 0.32 else 0.12, style.Twist, 0 }
	windup.Neck = { -0.08, -style.Twist * 0.3, 0 }
	windup.RightHip, windup.LeftHip = { 0.25, 0, 0 }, { 0.12, 0, 0 }
	windup.RightKnee, windup.LeftKnee = { -0.32, 0, 0 }, { -0.2, 0, 0 }
	strike.Waist = { style.Lean, -style.Twist * 0.75, 0 }
	strike.Neck = { -style.Lean * 0.2, style.Twist * 0.25, 0 }
	-- Keep existing ground-slam leg poses; directional casts drive off the rear leg.
	strike.RightHip = strike.RightHip or { 0.38, 0, 0 }
	strike.LeftHip = strike.LeftHip or { -0.12, 0, 0 }
	strike.RightKnee = strike.RightKnee or { -0.42, 0, 0 }
	strike.LeftKnee = strike.LeftKnee or { -0.08, 0, 0 }
	if kind == "Bolt" or kind == "Drill" then
		windup.RightShoulder = { 1.35, -0.35, 0.85 }
		windup.RightElbow = { 1.75, 0, 0 }
		strike.RightShoulder = { 1.85, 0.18, -0.18 }
	elseif kind == "Buff" then
		windup.RightShoulder, windup.LeftShoulder = { 0.95, 0.3, -0.25 }, { 0.95, -0.3, 0.25 }
		strike.RightShoulder, strike.LeftShoulder = { 2.1, -0.2, 0.7 }, { 2.1, 0.2, -0.7 }
	end
end

-- The action itself: the pose and how snappily the joints follow it.
local function actionPose(a, t: number, base)
	local kind, start, at = a.ActionKind, a.ActionStart, a.ActionAt
	if type(kind) ~= "string" or type(start) ~= "number" or type(at) ~= "number" or t < start then
		return nil, 0
	end
	local windup, strike = frames(kind, if a.ActionSide == -1 then -1 else 1)
	if not windup then
		return nil, 0
	end
	stageCast(kind, windup, strike)
	local style = CAST_STYLE[kind]
	local snapTime = if style then style.Snap else SNAP
	if t < at then
		-- Ease into the wind-up, then coil a little past it just before the
		-- release (the anticipation that sells the blow). A heavy trembles
		-- with the strain.
		local length = math.max(0.05, at - start)
		local p = (t - start) / length
		local pose = lerp(base, windup, ease(p * 1.4) * (1 + 0.12 * ease((p - 0.75) / 0.25)))
		if kind == "Heavy" or kind == "Nova" or kind == "Erupt" then
			local shake = 0.035 * ease((p - 0.5) / 0.5) * math.sin(t * 47)
			pose = add(pose, { RightShoulder = { shake, 0, 0 }, LeftShoulder = { -shake, 0, 0 } }, 1)
		end
		return pose, 18
	end
	local hold = if kind == "Dodge"
		then 0.4
		elseif kind == "Stagger" then 0.45
		elseif kind == "Buff" then 0.6
		else (if style then style.Follow else FOLLOW)
	-- A held beam keeps its cast pose while it pours (ActionHold).
	if type(a.ActionHold) == "number" then
		hold = math.max(hold, a.ActionHold - at)
	end
	local d = t - at
	if d < snapTime then
		-- The blow snaps through, past the strike pose.
		return lerp(windup, strike, ease(d / snapTime) * (1 + OVERSHOOT)), 45
	elseif d < hold then
		-- Follow-through: settle back onto the strike pose.
		return lerp(windup, strike, 1 + OVERSHOOT * (1 - ease((d - snapTime) / math.max(0.05, hold - snapTime)))), 35
	elseif d < hold + RECOVER then
		-- Recover to the stance, smoothly.
		return lerp(strike, base, ease((d - hold) / RECOVER)), 28
	end
	return nil, 0
end

-- The pose for these attributes at server time `t` (pure, for testing):
-- { [joint] = { x, y, z } }, plus how snappily to move into it. `rest`: a
-- player's body, which stands as its own animations have it between
-- actions (no fighting stance, no breathing).
local REST = {}
function RivalPose.pose(a, t: number, rest: boolean?): ({ [string]: { number } }, number)
	local base = if rest then REST else breathe(READY, t)
	local bat = a.CombatPoseProfile == "SahurBat"
	local weaponGuard = if a.WeaponBlock then WEAPON_GUARDS[a.CombatWeaponType] else nil
	local guard = weaponGuard or (if bat then BAT_GUARD else GUARD)
	-- Guard is authoritative: stale charge/cast attributes must never hide it.
	-- The server drops GuardUntil when an attack, dodge or guard break wins.
	local pose, speed
	if type(a.GuardUntil) == "number" and t < a.GuardUntil then
		pose, speed = if rest then guard else breathe(guard, t), 26
	else
		pose, speed = actionPose(a, t, base)
		if not pose then
			pose, speed = base, 10
		end
	end
	-- Hit reactions on top.
	if type(a.HurtAt) == "number" then
		local w = impulse(t - a.HurtAt, HURT_TIME)
		if w > 0 then
			local side = if a.HurtSide == -1 then -1 else 1
			pose = add(pose, FLINCH, w)
			pose = add(pose, { Waist = { 0, 0.18 * (side - 1), 0 } }, w)
			speed = math.max(speed, 40)
		end
	end
	if type(a.BlockedAt) == "number" then
		local w = impulse(t - a.BlockedAt, BLOCK_TIME)
		if w > 0 then
			pose = add(pose, if bat or weaponGuard then BAT_JOLT else JOLT, w)
			speed = math.max(speed, 40)
		end
	end
	return pose, speed
end

-- [model] = { Joints = { [joint] = { Object, Property, Rest } }, Angles = {...} }
-- (Not weak-keyed: a dropped entry would be rebuilt mid-pose.)
local rigs = {}

-- A joint and the CFrame that sets its resting offset: a Motor6D's C0, or for
-- rigs built with AnimationConstraints (Roblox's newer avatar joints) the
-- constraint's Attachment0. The rest value is remembered on the object the
-- first time it's seen, so a re-scan never mistakes an already-bent joint for
-- its rest pose (which would stack every pose on top of the last).
local function handle(model: Model, joint: string, partName: string)
	local part = model:FindFirstChild(partName)
	local object = part and part:FindFirstChild(joint)
	local target, property
	if object and object:IsA("Motor6D") then
		target, property = object, "C0"
	else
		local constraint = model:FindFirstChild(joint, true)
		if constraint and constraint:IsA("AnimationConstraint") and constraint.Attachment0 then
			target, property = constraint.Attachment0, "CFrame"
		end
	end
	if not target then
		return nil
	end
	local rest = target:GetAttribute("RestPose")
	if typeof(rest) ~= "CFrame" then
		rest = (target :: any)[property]
		target:SetAttribute("RestPose", rest)
	end
	return { Object = target, Property = property, Rest = rest }
end

-- Its joints. With streaming on, the body parts can arrive after the model
-- itself, so any joint not found yet is looked for again every half second.
local function rigOf(model: Model, clock: number)
	local rig = rigs[model]
	if not rig then
		rig = { Joints = {}, Angles = {}, Found = 0, NextScan = 0 }
		rigs[model] = rig
	end
	if rig.Found < JOINT_COUNT and clock >= rig.NextScan then
		rig.NextScan = clock + 0.5
		for joint, partName in JOINTS do
			local entry = rig.Joints[joint]
			if not entry or entry.Object.Parent == nil then
				local found = handle(model, joint, partName)
				if found then
					rig.Joints[joint] = found
					rig.Angles[joint] = rig.Angles[joint] or { 0, 0, 0 }
				end
			end
		end
		rig.Found = 0
		for _ in rig.Joints do
			rig.Found += 1
		end
	end
	return rig
end

-- How many joints it can pose (for diagnostics).
function RivalPose.jointCount(model: Model): number
	local count = 0
	for joint, partName in JOINTS do
		if handle(model, joint, partName) then
			count += 1
		end
	end
	return count
end

local ATTRIBUTES = {
	"CombatWeaponType",
	"WeaponBlock",
	"CombatPoseProfile",
	"ActionKind",
	"ActionStart",
	"ActionAt",
	"ActionSide",
	"ActionHold",
	"GuardUntil",
	"HurtAt",
	"HurtSide",
	"BlockedAt",
}

-- Call every frame (clients pose every body: Client.BodyPoses) with the
-- model and server time. Joints only change when they move noticeably.
local nextSweep = 0
function RivalPose.update(model: Model?, dt: number, now: number, clock: number?, rest: boolean?)
	local tick = clock or now
	if tick >= nextSweep then
		nextSweep = tick + 1
		for known in rigs do
			if not known.Parent then
				rigs[known] = nil -- gone: forget it
			end
		end
	end
	if not model or not model.Parent then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local rig = rigOf(model, clock or now)
	local attrs = {}
	for _, name in ATTRIBUTES do
		attrs[name] = model:GetAttribute(name)
	end
	local target, speed = RivalPose.pose(attrs, now, rest)
	local alpha = 1 - math.exp(-speed * math.min(dt, 0.1))
	for joint, entry in rig.Joints do
		local angles = rig.Angles[joint]
		local to = target[joint] or { 0, 0, 0 }
		local moved = 0
		for i = 1, 3 do
			local step = (to[i] - angles[i]) * alpha
			angles[i] += step
			moved = math.max(moved, math.abs(step))
		end
		if moved > 0.002 or not entry.Written then
			entry.Written = true;
			(entry.Object :: any)[entry.Property] = entry.Rest * CFrame.Angles(angles[1], angles[2], angles[3])
		end
	end
end

return RivalPose
