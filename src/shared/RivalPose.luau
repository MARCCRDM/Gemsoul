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
local STRIDE_LENGTH = 4.5 -- studs walked per full guarded stride (two steps)

-- Angles are radians about the joint's X (positive swings a limb forward and
-- up, or leans the torso back), Y (twists left) and Z (positive raises the
-- right arm outward; negative the left).
-- Fighting stance: shield arm forward, sword held out, knees soft.
local READY = {
	RightShoulder = { 0.45, 0, 0.12 },
	RightElbow = { 0.85, 0, 0 },
	LeftShoulder = { 0.9, 0, 0.3 },
	LeftElbow = { 1.15, 1.45, 0 },
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
-- The shield arm held up in front during a sword's blows, as in the guard
-- (GUARD): the forearm upright before the chest, the shield's face square to
-- the front.
local SHIELD_UP = {
	LeftShoulder = { 1.4, -0.55, 0.55 },
	LeftElbow = { 2.05, 0.45, 0 },
}

local function frames(kind: string, s: number, shield: boolean?)
	if kind == "Deploy" then
		return {
			Waist = { -0.32, 0, 0 },
			Neck = { 0.18, 0, 0 },
			RightShoulder = { 0.55, 0, 0.2 },
			LeftShoulder = { 0.75, 0, -0.3 },
			RightElbow = { 0.8, 0, 0 },
			LeftElbow = { 1, 0, 0 },
			RightHip = { 0.75, 0, 0 },
			LeftHip = { 0.35, 0, 0 },
			RightKnee = { -1.05, 0, 0 },
			LeftKnee = { -0.65, 0, 0 },
		}, {
			Waist = { -0.08, 0.12, 0 },
			Neck = { 0, -0.1, 0 },
			RightShoulder = { 0.3, 0, 0.12 },
			LeftShoulder = { 0.8, 0, -0.25 },
			RightElbow = { 0.5, 0, 0 },
			LeftElbow = { 0.85, 0, 0 },
			RightHip = { -0.1, 0, 0 },
			LeftHip = { 0.4, 0, 0 },
			RightKnee = { -0.12, 0, 0 },
			LeftKnee = { -0.45, 0, 0 },
		}
	elseif kind == "Mine" then
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
		-- Shaped from the sword's real path (fist grip, blade out past the
		-- thumb): the tip sweeps a wide arc across the front of the body at
		-- chest height, so the slash drawn along it (Client.BladeTrails) reads
		-- as a cut at the foe. Hips and shoulders drive it; the head stays on
		-- the foe; the front foot steps in; the shield stays up.
		-- s = 1, the forehand: cocked high behind the right shoulder, cutting
		-- down and across to low on the left. s = -1, the backhand: from
		-- behind the left shoulder, flat across to the right.
		local leftShoulder = if shield then SHIELD_UP.LeftShoulder else { 0.6, 0, -0.3 }
		local leftElbow = if shield then SHIELD_UP.LeftElbow else { 0.9, 0, 0 }
		if s >= 0 then
			return {
				Waist = { 0, -0.77, 0.19 },
				Neck = { -0.04, 0.45, 0 },
				RightShoulder = { -0.96, -1.19, -1.69 },
				RightElbow = { 2.31, 1.55, 0 },
				LeftShoulder = leftShoulder,
				LeftElbow = leftElbow,
				RightHip = { 0.1, 0, 0 },
				LeftHip = { 0.18, 0, 0 },
				RightKnee = { -0.3, 0, 0 },
				LeftKnee = { -0.2, 0, 0 },
			}, {
				Waist = { -0.18, 0.71, 0.3 },
				Neck = { 0.06, -0.45, 0 },
				RightShoulder = { 0.48, 0.08, -0.02 },
				RightElbow = { 1.41, 1.6, 0 },
				LeftShoulder = leftShoulder,
				LeftElbow = leftElbow,
				RightHip = { 0.55, 0, 0 },
				LeftHip = { -0.25, 0, 0 },
				RightKnee = { -0.6, 0, 0 },
				LeftKnee = { -0.1, 0, 0 },
			}
		end
		return {
			Waist = { -0.01, 0.67, 0.22 },
			Neck = { -0.04, -0.55, 0 },
			RightShoulder = { 1.11, 0.08, -0.81 },
			RightElbow = { 0.97, 1.6, 0 },
			LeftShoulder = leftShoulder,
			LeftElbow = leftElbow,
			RightHip = { 0.15, 0, 0 },
			LeftHip = { 0.1, 0, 0 },
			RightKnee = { -0.25, 0, 0 },
			LeftKnee = { -0.25, 0, 0 },
		}, {
			Waist = { -0.09, -0.66, 0.04 },
			Neck = { 0.04, 0.45, 0 },
			RightShoulder = { 0.82, 0.12, 2.0 },
			RightElbow = { 2.16, 1.6, 0 },
			LeftShoulder = leftShoulder,
			LeftElbow = leftElbow,
			RightHip = { 0.5, 0, 0 },
			LeftHip = { -0.2, 0, 0 },
			RightKnee = { -0.55, 0, 0 },
			LeftKnee = { -0.1, 0, 0 },
		}
	elseif kind == "Heavy" and shield then
		-- One-handed overhead chop, shaped from the sword's real path: raised
		-- high with the blade back over the head, the tip comes over the top
		-- and slams down to the ground in front, the body folding into it;
		-- the shield stays braced in front.
		return {
			Waist = { 0.14, -0.02, 0 },
			Neck = { 0.12, 0, 0 },
			RightShoulder = { 2.36, 0.84, 0.2 },
			RightElbow = { 1.07, -1.07, 0 },
			LeftShoulder = SHIELD_UP.LeftShoulder,
			LeftElbow = SHIELD_UP.LeftElbow,
			RightHip = { 0.15, 0, 0 },
			RightKnee = { -0.2, 0, 0 },
		}, {
			Waist = { -0.47, 0.14, 0.08 },
			Neck = { -0.2, 0, 0 },
			RightShoulder = { 0.64, 0.66, -1.17 },
			RightElbow = { 2.08, -1.6, 0 },
			LeftShoulder = SHIELD_UP.LeftShoulder,
			LeftElbow = SHIELD_UP.LeftElbow,
			RightHip = { 0.6, 0, 0 },
			LeftHip = { -0.25, 0, 0 },
			RightKnee = { -0.7, 0, 0 },
			LeftKnee = { -0.3, 0, 0 },
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

-- Guard: square to the foe, the shield forearm raised upright in front of the
-- chest with its face turned straight forward, the sword drawn back low behind
-- it ready to answer, crouched behind the shield.
local GUARD = {
	Waist = { -0.15, -0.08, 0 },
	Neck = { -0.08, 0.05, 0 },
	LeftShoulder = SHIELD_UP.LeftShoulder,
	LeftElbow = SHIELD_UP.LeftElbow,
	RightShoulder = { 0.45, 0, 0.1 },
	RightElbow = { 0.95, 0, 0 },
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

-- Walking behind the guard: short, braced steps that keep the shield square.
-- `phase` runs through a stride (radians), `forward` and `side` are how much of
-- the walk is forward (negative: backing off) and sideways (positive: to its
-- right), `amount` 0..1 how fast. Pure, for testing: offsets to add on top of
-- the guard (RivalPose.update does, while the guard's up and the body moves).
function RivalPose.guardStep(phase: number, forward: number, side: number, amount: number)
	local swing, lift = math.sin(phase), math.cos(phase)
	local rightUp, leftUp = math.max(0, lift), math.max(0, -lift)
	local stride = 0.42 * amount * forward
	local shuffle = 0.16 * amount * side
	local step = 0.22 * amount * math.abs(side) -- sidesteps lift the foot too
	local bob = 0.035 * amount * math.cos(2 * phase)
	return {
		RightHip = { stride * swing + step * rightUp, 0, shuffle * swing },
		LeftHip = { -stride * swing + step * leftUp, 0, shuffle * swing },
		RightKnee = { -0.55 * amount * rightUp, 0, 0 },
		LeftKnee = { -0.55 * amount * leftUp, 0, 0 },
		Waist = { bob, 0.05 * amount * forward * swing, 0 },
		-- The arms ride the step a little but the shield stays put.
		LeftShoulder = { 0.6 * bob, 0, 0 },
		RightShoulder = { bob, 0, 0 },
	}
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
	local shield = not a.WeaponBlock
	local windup, strike = frames(kind, if a.ActionSide == -1 then -1 else 1, shield)
	if not windup then
		return nil, 0
	end
	if kind == "Deploy" then
		-- A planted step and uncoiling shoulders, not an attack's snap/overshoot.
		local elapsed = t - start
		if elapsed < 0.22 then
			return lerp(base, windup, ease(elapsed / 0.22)), 24
		end
		if elapsed < 0.70 then
			return lerp(windup, strike, ease((elapsed - 0.22) / 0.48)), 24
		end
		if elapsed < 1.20 then
			return lerp(strike, base, ease((elapsed - 0.70) / 0.50)), 20
		end
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
-- R6 bodies (an avatar type that allows them): their joints sit on the Torso
-- under other names, and there are no elbows or knees. The waist bends the
-- whole body at the root.
local R6 = {
	Waist = { "HumanoidRootPart", "RootJoint" },
	Neck = { "Torso", "Neck" },
	RightShoulder = { "Torso", "Right Shoulder" },
	LeftShoulder = { "Torso", "Left Shoulder" },
	RightHip = { "Torso", "Right Hip" },
	LeftHip = { "Torso", "Left Hip" },
}

local function active(object: Instance?): boolean
	return object ~= nil and (object :: any).Enabled ~= false
end

-- The joint that actually moves this limb: an enabled Motor6D (its C0), or
-- the AnimationConstraint that replaced it (its Attachment0) when the
-- place uses Roblox's upgraded avatar joints, which can leave the old,
-- switched-off Motor6D in place: bending that one moved nothing on
-- players' avatars while the rival's own rig worked.
local function handle(model: Model, joint: string, partName: string)
	local part = model:FindFirstChild(partName)
	local object = part and part:FindFirstChild(joint)
	if not object and not part then
		-- An R6 body.
		local r6 = R6[joint]
		local holder = r6 and model:FindFirstChild(r6[1])
		object = holder and holder:FindFirstChild(r6[2])
	end
	local target, property
	if object and object:IsA("Motor6D") and active(object) then
		target, property = object, "C0"
	else
		local constraint = if object and object:IsA("AnimationConstraint") then object else nil
		if not constraint then
			for _, d in model:GetDescendants() do
				if d.Name == joint and d:IsA("AnimationConstraint") then
					constraint = d
					break
				end
			end
		end
		if constraint and active(constraint) and constraint.Attachment0 then
			target, property = constraint.Attachment0, "CFrame"
		elseif object and object:IsA("Motor6D") then
			target, property = object, "C0" -- (switched off, but it's all there is)
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
	return { Object = target, Property = property, Rest = rest, R6 = R6[joint] ~= nil and part == nil }
end

-- Its joints. With streaming on, the body parts can arrive after the model
-- itself, so any joint not found yet is looked for again every half second.
local function rigOf(model: Model, clock: number)
	local rig = rigs[model]
	if not rig then
		rig = { Joints = {}, Angles = {}, Found = 0, NextScan = 0, Resets = 0, Updates = 0 }
		rigs[model] = rig
	end
	-- A joint can be replaced under us (a rebuilt body): look again then too.
	local lost = false
	for _, entry in rig.Joints do
		if entry.Object.Parent == nil then
			lost = true
			break
		end
	end
	if (rig.Found < JOINT_COUNT or lost) and clock >= rig.NextScan then
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

-- What posing a body has done so far (for diagnostics, the DEV panel):
-- joints found (and whether as Motor6Ds), frames posed, how often something
-- else reset a bent joint, the largest bend now (radians) and the action.
function RivalPose.inspect(model: Model)
	local rig = rigs[model]
	if not rig then
		return nil
	end
	local motors, constraints, r6, bend = 0, 0, 0, 0
	for joint, entry in rig.Joints do
		if entry.R6 then
			r6 += 1
		elseif entry.Property == "C0" then
			motors += 1
		else
			constraints += 1
		end
		for _, angle in rig.Angles[joint] do
			bend = math.max(bend, math.abs(angle))
		end
	end
	return {
		Found = rig.Found,
		Motors = motors,
		Updates = rig.Updates,
		Resets = rig.Resets,
		Bend = bend,
		-- How the body's joints were found: R15 Motor6Ds, upgraded joints
		-- (AnimationConstraints) or an R6 body.
		Kind = if r6 > 0 then "R6" elseif constraints > motors then "upgraded joints" else "Motor6D",
		Action = rig.Action,
	}
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

-- Blows a blade cuts with.
local STRIKES = { Slash = true, Heavy = true, Sweep = true, Cross = true }

-- Whether this body's blade is cutting through a blow right now (as posed
-- here, so a player's blow replayed late counts when it shows).
function RivalPose.striking(model: Model): boolean
	local rig = rigs[model]
	return rig ~= nil and rig.Striking == true
end

local function velocityOf(root: BasePart): Vector3
	return root.AssemblyLinearVelocity
end

-- Call every frame (clients pose every body: Client.BodyPoses) with the
-- model and server time. Joints only change when they move noticeably.
local nextSweep = 0
-- `guarding`: known to be blocking right now (a player's own "Blocking"
-- flag), whatever GuardUntil says.
function RivalPose.update(model: Model?, dt: number, now: number, clock: number?, rest: boolean?, guarding: boolean?)
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
	if guarding and not (type(attrs.GuardUntil) == "number" and attrs.GuardUntil > now) then
		attrs.GuardUntil = now + 0.25
	end
	-- A player's blow is announced as it lands (no wind-up), so it reaches
	-- other screens after it's over and showed as a twitch at most. An
	-- instant slash or heavy is replayed from the moment it's seen here,
	-- behind a short wind-up. (The hit itself is the server's; only the
	-- body is a moment behind. The rival announces its wind-ups ahead.)
	local start, at = attrs.ActionStart, attrs.ActionAt
	if
		(attrs.ActionKind == "Slash" or attrs.ActionKind == "Heavy")
		and type(start) == "number"
		and type(at) == "number"
		and at - start < 0.05
	then
		if rig.SeenStart ~= start then
			rig.SeenStart, rig.SeenAt = start, math.min(now, at + 1)
		end
		local lead = if attrs.ActionKind == "Heavy" then 0.3 else 0.18
		attrs.ActionStart, attrs.ActionAt = rig.SeenAt, rig.SeenAt + lead
	end
	local target, speed = RivalPose.pose(attrs, now, rest)
	rig.Updates += 1
	-- The moment a blade blow cuts through (for its slash: Client.BladeTrails).
	local struck = attrs.ActionAt
	rig.Striking = STRIKES[attrs.ActionKind] == true
		and type(struck) == "number"
		and now >= struck - 0.02
		and now <= struck + SNAP + 0.1
		and not (type(attrs.GuardUntil) == "number" and attrs.GuardUntil > now)
	local guardUp = type(attrs.GuardUntil) == "number" and attrs.GuardUntil > now
	rig.Action = if guardUp then "Guard" else (if type(attrs.ActionKind) == "string" then attrs.ActionKind else nil)
	local step = math.min(dt, 0.1)
	-- Walking with the guard up: its own braced steps (RivalPose.guardStep),
	-- in place of the body's walk animation, which would swing the shield arm
	-- about (held off by RivalPose.holdGuards).
	local root = model:FindFirstChild("HumanoidRootPart")
	local pace = 0
	local moving, velocity = false, nil
	if guardUp and root and root:IsA("BasePart") then
		moving, velocity = pcall(velocityOf, root)
	end
	if moving and velocity then
		local v = root.CFrame:VectorToObjectSpace(velocity)
		pace = math.sqrt(v.X * v.X + v.Z * v.Z)
		if pace > 0.5 then
			rig.Forward, rig.Side = -v.Z / pace, v.X / pace
		else
			pace = 0
		end
	end
	local follow = 1 - math.exp(-10 * step)
	rig.Stride = (rig.Stride or 0) + (math.min(1, pace / 6) - (rig.Stride or 0)) * follow
	rig.Phase = ((rig.Phase or 0) + pace * step * 2 * math.pi / STRIDE_LENGTH) % (2 * math.pi)
	if rig.Stride > 0.01 then
		target = add(target, RivalPose.guardStep(rig.Phase, rig.Forward or 1, rig.Side or 0, rig.Stride), 1)
	end
	rig.Hold = (rig.Hold or 0) + ((if guardUp then 1 else 0) - (rig.Hold or 0)) * (1 - math.exp(-14 * step))
	local alpha = 1 - math.exp(-speed * step)
	for joint, entry in rig.Joints do
		local angles = rig.Angles[joint]
		local to = target[joint] or { 0, 0, 0 }
		local moved = 0
		for i = 1, 3 do
			local step = (to[i] - angles[i]) * alpha
			angles[i] += step
			moved = math.max(moved, math.abs(step))
		end
		-- The bend turns about the parent's own axes at the joint, so a rig
		-- whose joint frames are rotated (R6, some avatars) bends the same way.
		-- Written when it moves, or when something else has put the joint
		-- back since (counted: RivalPose.inspect shows it).
		local current = (entry.Object :: any)[entry.Property]
		local overridden = entry.Last ~= nil
			and (
				(current.Position - entry.Last.Position).Magnitude > 1e-3
				or (current.LookVector - entry.Last.LookVector).Magnitude > 1e-3
				or (current.UpVector - entry.Last.UpVector).Magnitude > 1e-3
			)
		if overridden then
			rig.Resets += 1
		end
		if moved > 0.002 or not entry.Last or overridden then
			entry.Last = CFrame.new(entry.Rest.Position)
				* CFrame.Angles(angles[1], angles[2], angles[3])
				* entry.Rest.Rotation;
			(entry.Object :: any)[entry.Property] = entry.Last
		end
	end
end

-- The body's own animations (its walk, run and idle) bend the same joints on
-- top of the pose. While the guard's up they're held off, so the shield stays
-- square and the legs take the guarded steps instead; eased in and out with
-- the guard. Call after animations are applied each frame
-- (RunService.Stepped; Client.BodyPoses does).
function RivalPose.holdGuards()
	for model, rig in rigs do
		local w = rig.Hold
		if w and w > 0.01 and model.Parent then
			if rig.Root == nil then
				local lowerTorso = model:FindFirstChild("LowerTorso")
				local motor = lowerTorso and lowerTorso:FindFirstChild("Root")
				rig.Root = if motor and motor:IsA("Motor6D") then motor else false
			end
			for _, entry in rig.Joints do
				local object = entry.Object
				if object:IsA("Motor6D") then
					object.Transform = object.Transform:Lerp(CFrame.identity, w)
				end
			end
			if rig.Root then
				rig.Root.Transform = rig.Root.Transform:Lerp(CFrame.identity, w)
			end
		end
	end
end

return RivalPose
