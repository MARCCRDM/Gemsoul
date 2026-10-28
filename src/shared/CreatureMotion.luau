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
-- Each blow winds up into Wind (by its ActionAt), strikes into Hit (a
-- touch past it, then back: the blow has weight), holds there a beat as it
-- lands, and settles back. Yaw, Roll and Tail turn to the blow's side
-- (ActionSide). A cast trembles as it gathers; a heavy shivers at the top
-- of its wind-up, just before it comes down.
Motion.Strike = 0.1 -- seconds from its wind-up pose into the blow
Motion.Hold = 0.06 -- held on the blow as it lands
Motion.Settle = 0.3 -- and back to rest
Motion.Overshoot = 1.7 -- how far past the blow it carries (a back-out ease's tension)

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

-- The roster's kinds (Shared.KaijuRoster): each moves like the first-four
-- kind its body is nearest to (`like`), with blows of its own where they
-- differ, after its blows' names (KaijuRoster's Fight.Names). A flyer's
-- wings beat with its Arm (Motion.apply), so a flyer's blows use Arm for
-- a wingbeat.
local function like(base: string, own)
	local keys = table.clone(Motion.Fight[base])
	for name, key in own or {} do
		keys[name] = key
	end
	return keys
end
local FLYER = {
	-- A peck: up on its wings, then down beak first.
	Light = {
		Wind = { Pitch = 0.2, Lift = 0.2, Jaw = 0.5, Arm = 0.6 },
		Hit = { Pitch = -0.35, Lift = -0.15, Push = 0.5, Jaw = -0.1 },
	},
	-- A dive: high on beating wings, then down onto it.
	Heavy = {
		Wind = { Pitch = 0.3, Lift = 0.45, Arm = 1.0, Jaw = 0.4 },
		Hit = { Pitch = -0.45, Lift = -0.2, Push = 0.6, Jaw = 0.6 },
	},
	Lunge = { Wind = { Pitch = 0.15, Lift = 0.25, Arm = 0.8 }, Hit = { Pitch = -0.3, Push = 0.7 } },
	Cast = { Wind = { Pitch = 0.35, Lift = 0.3, Jaw = 0.7, Arm = 1.2 }, Hit = { Pitch = -0.05, Jaw = 0.9, Arm = 0.4 } },
	-- Wings wrapped round it.
	Guard = { Pitch = 0.15, Lift = 0.1, Arm = 1.1 },
}
-- Two arms up, then brought down together (a slam, a pound, a crush).
local SLAM = {
	Wind = { Pitch = 0.3, Lift = 0.1, Arm = 1.8, Jaw = 0.3 },
	Hit = { Pitch = -0.25, Lift = -0.18, Arm = 0.3, Jaw = 0.5 },
}
-- Dropped low, then bursting up at it (from a burrow, from an ambush).
local BURST = {
	Wind = { Lift = -0.4, Pitch = -0.1, Jaw = 0.2 },
	Hit = { Lift = 0.35, Pitch = 0.3, Jaw = 0.8, Arm = 1.0, Push = 0.3 },
}
-- Coiled one way, then a whole-body spin (a tail sweep, a spin).
local SPIN = like("Razorback").Heavy
local ROAR = { Wind = { Pitch = 0.35, Jaw = 0.9, Arm = 0.6 }, Hit = { Pitch = -0.1, Jaw = 1.0, Arm = 0.3 } }

local F = Motion.Fight
-- Tanks
F.Ironhide = like("Carapace", {
	-- Spine Roll: tucked in, then rolled through it.
	Heavy = { Wind = { Lift = -0.3, Pitch = -0.2 }, Hit = { Roll = 0.9, Yaw = -0.6, Push = 0.6, Lift = -0.1 } },
	-- Curled into its spikes.
	Guard = { Lift = -0.4, Pitch = -0.2 },
})
F.Shellfire = like("Carapace", {
	-- Spin Dive: up on its jets, then spinning down.
	Heavy = { Wind = { Lift = 0.35, Pitch = 0.2 }, Hit = { Yaw = -1.5, Lift = -0.15, Push = 0.3 } },
})
F.Mossback = like("Bulwark", {
	-- Vine Lash: a long arm drawn back and whipped across.
	Light = {
		Wind = { Yaw = 0.35, Arm = -0.7, Pitch = 0.08 },
		Hit = { Yaw = -0.45, Arm = 1.6, Pitch = -0.1, Push = 0.2 },
		OneArm = true,
	},
	-- Root Burst: both vines up, then driven into the ground.
	Heavy = SLAM,
})
F.Bastion = like("Razorback", {
	-- Paw Strike: up on its haunches and down with a paw.
	Light = { Wind = { Pitch = 0.2, Lift = 0.05 }, Hit = { Pitch = -0.2, Push = 0.4, Jaw = 0.3 } },
	-- Guardian Slam: rears right up, then crashes down.
	Heavy = { Wind = { Pitch = 0.42, Lift = 0.22, Jaw = 0.5 }, Hit = { Pitch = -0.25, Lift = -0.2, Jaw = 0.7 } },
	Cast = ROAR,
	-- Crouched, mane forward.
	Guard = { Pitch = -0.15, Lift = -0.2, Jaw = 0.2 },
})
F.Hulkshell = like("Bulwark", {
	-- Ground Pound: both fists up, then down.
	Heavy = SLAM,
	-- Knuckle Charge: head down, knuckles first.
	Lunge = { Wind = { Pitch = -0.3, Lift = -0.1, Arm = -0.3 }, Hit = { Pitch = -0.4, Push = 0.6, Arm = 0.8 } },
	-- Down under its shell.
	Guard = { Lift = -0.3, Pitch = -0.2, Arm = 0.6 },
})
-- Warriors
F.Emberjaw = like("Bulwark", { Heavy = SPIN, Cast = ROAR })
F.Dreadmaw = like("Razorback", {
	-- Snap: that great jaw flung wide and slammed shut.
	Light = { Wind = { Pitch = 0.15, Push = -0.25, Jaw = 0.9 }, Hit = { Pitch = -0.2, Push = 0.5, Jaw = -0.1 } },
	-- Lunge Bite: reared back, jaws wide, then a long lunge.
	Heavy = { Wind = { Pitch = 0.3, Push = -0.3, Jaw = 1.1 }, Hit = { Pitch = -0.3, Push = 0.8, Jaw = -0.1 } },
	Lunge = { Wind = { Pitch = 0.2, Lift = -0.15, Jaw = 1.0 }, Hit = { Pitch = -0.25, Push = 0.8, Jaw = 0 } },
	Cast = ROAR,
})
F.Hornblade = like("Bulwark", {
	-- Horn Gore: head down, then tossed up.
	Light = { Wind = { Pitch = -0.25, Push = -0.1 }, Hit = { Pitch = 0.2, Push = 0.4, Jaw = 0.3 } },
	Heavy = BURST,
	Lunge = { Wind = { Pitch = -0.3, Lift = -0.15 }, Hit = { Pitch = -0.35, Push = 0.7 } },
	Guard = { Pitch = -0.2, Lift = -0.25, Arm = 0.8 },
})
F.Titanfin = like("Bulwark", { Heavy = SPIN })
F.Drillhorn = like("Bulwark", {
	-- Drill Jab: one drill driven straight in.
	Light = { Wind = { Yaw = 0.2, Arm = 0.2, Push = -0.15 }, Hit = { Yaw = -0.2, Arm = 1.4, Push = 0.4 }, OneArm = true },
	-- Drill Dive: reared up, both drills high, then dived in.
	Heavy = { Wind = { Pitch = 0.35, Lift = 0.15, Arm = 1.8 }, Hit = { Pitch = -0.4, Push = 0.6, Arm = 1.2 } },
})
F.Grandape = like("Bulwark", {
	-- Chest-Beat Slam: arms beating its chest, then slammed down.
	Heavy = {
		Wind = { Pitch = 0.3, Lift = 0.08, Arm = 1.2, Jaw = 0.6 },
		Hit = { Pitch = -0.28, Lift = -0.18, Arm = 0.3, Jaw = 0.5 },
	},
	Lunge = F.Hulkshell.Lunge,
	Cast = ROAR,
})
F.Bladebrow = like("Bulwark", {
	-- Twin Fist: both fists at once.
	Light = { Wind = { Pitch = 0.08, Arm = -0.4, Push = -0.1 }, Hit = { Pitch = -0.12, Arm = 1.3, Push = 0.35 } },
	-- Head Spear: drawn back, then the brow blade driven through.
	Heavy = { Wind = { Pitch = 0.3, Push = -0.25, Arm = -0.3 }, Hit = { Pitch = -0.4, Push = 0.7, Arm = 0.5 } },
	Lunge = { Wind = { Pitch = 0.2, Push = -0.2 }, Hit = { Pitch = -0.38, Push = 0.75 } },
})
-- Ranged
F.Stormwing = FLYER
F.Thornlob = like("Razorback", {
	-- Web Shot: reared up, then spat.
	Heavy = { Wind = { Pitch = 0.3, Lift = 0.1, Jaw = 0.6 }, Hit = { Pitch = -0.1, Push = -0.1, Jaw = 0.8 } },
	-- Skitter: low and quick.
	Lunge = { Wind = { Lift = -0.15, Pitch = -0.05 }, Hit = { Lift = -0.05, Push = 0.5 } },
	Guard = { Lift = -0.3, Pitch = 0.1, Jaw = 0.3 },
})
F.Starspine = like("Bulwark", {
	-- Crystal Spire: reared up, then stamping a spire up out of the ground.
	Heavy = { Wind = { Pitch = 0.35, Lift = 0.1, Arm = 1.2, Jaw = 0.5 }, Hit = { Pitch = -0.2, Lift = -0.15, Arm = 0.4 } },
	Cast = ROAR,
})
F.Nulltalon = like("Scythe", {
	-- Barrier Shot: both talons thrust out.
	Heavy = { Wind = { Pitch = 0.2, Arm = 0.4, Push = -0.15 }, Hit = { Pitch = -0.1, Arm = 1.5, Push = 0.2 } },
	-- Blink Strike: a low crouch, then gone at it.
	Lunge = { Wind = { Lift = -0.3, Pitch = -0.15 }, Hit = { Lift = 0.1, Push = 0.8, Arm = 0.8 } },
})
F.Sporeback = like("Carapace", {
	-- Sludge Slap: lurching forward.
	Light = { Wind = { Pitch = 0.15, Push = -0.15 }, Hit = { Pitch = -0.2, Push = 0.4, Jaw = 0.4 } },
	-- Smog Wave: swelling up, then bursting.
	Heavy = { Wind = { Lift = 0.25, Pitch = 0.2, Jaw = 0.4 }, Hit = { Lift = -0.2, Pitch = -0.1, Jaw = 0.9 } },
	Lunge = { Wind = { Lift = -0.2 }, Hit = { Lift = -0.1, Push = 0.5 } },
	-- Squashed flat.
	Guard = { Lift = -0.35 },
})
F.Voltfin = like("Razorback", {
	Lunge = { Wind = { Lift = -0.15, Yaw = 0.3 }, Hit = { Lift = -0.05, Push = 0.5, Yaw = -0.3 } },
})
-- Assassins
F.Sickleclaw = like("Scythe", {
	-- Buzzsaw Rush: spinning through it, saw first.
	Heavy = { Wind = { Pitch = -0.15, Lift = -0.1, Arm = 0.8 }, Hit = { Yaw = -1.4, Push = 0.6, Arm = 1.0 } },
})
F.Sickleclaw.Lunge = F.Sickleclaw.Heavy
F.Nightwing = like("Razorback", FLYER)
F.Nightwing.Heavy = {
	-- Horn Impale: high, then plunged head first.
	Wind = { Pitch = 0.35, Lift = 0.4, Arm = 1.0 },
	Hit = { Pitch = -0.55, Lift = -0.15, Push = 0.6, Jaw = 0.3 },
}
F.Longcoil = like("Razorback", {
	-- Constrict: the neck thrown round it and squeezed.
	Heavy = { Wind = { Yaw = 0.6, Tail = -0.8, Jaw = 0.4 }, Hit = { Yaw = -1.0, Tail = 1.2, Roll = 0.2, Jaw = 0.6 } },
	-- Serpent Strike: reared back, then a long strike.
	Lunge = { Wind = { Pitch = 0.25, Push = -0.3, Jaw = 0.8 }, Hit = { Pitch = -0.3, Push = 0.8, Jaw = 0 } },
})
F.Glassjaw = like("Razorback", { Heavy = BURST })
F.Razorclaw = like("Razorback", {
	-- Claw: up and down on its forelegs.
	Light = { Wind = { Pitch = 0.2, Lift = 0.05, Jaw = 0.4 }, Hit = { Pitch = -0.2, Push = 0.45, Jaw = 0.2 } },
	-- Tail Pincer: the tail swung over and snapped.
	Heavy = { Wind = { Yaw = 0.5, Tail = -0.8, Pitch = 0.1 }, Hit = { Yaw = -0.9, Tail = 1.3, Pitch = -0.1 } },
	-- Swoop: up on its wings, then down on it.
	Lunge = FLYER.Lunge,
})
F.Lankshade = like("Scythe", {
	-- Stomp Down: up on those long legs, then dropped on it.
	Heavy = { Wind = { Lift = 0.25, Pitch = 0.2, Arm = 0.8 }, Hit = { Lift = -0.25, Pitch = -0.3, Arm = 0.2, Jaw = 0.6 } },
	-- Long Stride: one long step in.
	Lunge = { Wind = { Pitch = 0.1, Lift = 0.1 }, Hit = { Pitch = -0.25, Push = 0.8, Arm = 0.6 } },
})
-- Breakers
F.Triskull = like("Bulwark", {
	-- Triple Snap: all three heads at once (Motion.apply: heads snap with the jaw).
	Light = { Wind = { Pitch = 0.12, Push = -0.2, Jaw = 0.8 }, Hit = { Pitch = -0.2, Push = 0.45, Jaw = -0.1 } },
	-- Gravity Bolt: reared up, all jaws wide, then loosed.
	Heavy = { Wind = { Pitch = 0.35, Jaw = 0.9, Lift = 0.1 }, Hit = { Pitch = -0.15, Jaw = 1.0, Push = 0.2 } },
	Lunge = FLYER.Lunge,
	Cast = ROAR,
})
F.Brightsteel = like("Bulwark", {
	-- Piston Punch: one fist, pistoned straight out.
	Light = { Wind = { Yaw = 0.2, Arm = -0.3, Push = -0.15 }, Hit = { Yaw = -0.25, Arm = 1.5, Push = 0.45 }, OneArm = true },
	-- Finger Missiles: both arms up, then the recoil.
	Heavy = { Wind = { Pitch = 0.15, Arm = 1.4 }, Hit = { Pitch = 0.05, Arm = 1.2, Push = -0.25 } },
	-- Thruster Rush: up on its thrusters and in.
	Lunge = { Wind = { Pitch = -0.1, Lift = 0.15 }, Hit = { Pitch = -0.3, Lift = 0.2, Push = 0.7 } },
})
F.Dreadcrown = like("Bulwark", {
	-- Oxygen Crush: both pincers high, then crushed together.
	Heavy = SLAM,
	-- Crab Rush: side-on, then in.
	Lunge = { Wind = { Roll = 0.3, Lift = -0.1 }, Hit = { Roll = -0.2, Push = 0.6, Arm = 0.8 } },
	Cast = ROAR,
})
-- Warden
F.Moonmoth = FLYER
F.Skyjelly = like("Razorback", {
	-- Tendril Sting: bobs up on its tendrils, then drops onto it.
	Light = { Wind = { Lift = 0.3, Pitch = 0.1 }, Hit = { Lift = -0.15, Pitch = -0.2, Push = 0.35 } },
	-- Static Pulse: squeezed low, then swelling up bright.
	Heavy = { Wind = { Lift = -0.3, Jaw = 0.3 }, Hit = { Lift = 0.35, Jaw = 0.8, Push = 0.2 } },
	Lunge = { Wind = { Lift = 0.25 }, Hit = { Lift = 0.1, Push = 0.6 } },
	-- A pulse: drawn in, then swelling as its light goes out.
	Cast = { Wind = { Lift = -0.25, Jaw = 0.4 }, Hit = { Lift = 0.4, Jaw = 0.9 } },
	Guard = { Lift = -0.2, Pitch = 0.1, Jaw = 0.2 },
})

-- The rest of the roster (Shared.KaijuRosterMore), the same way.
-- Up, then its whole weight dropped onto it (a body drop, a belly slam).
local DROP = { Wind = { Lift = 0.35, Pitch = 0.25 }, Hit = { Lift = -0.3, Pitch = -0.2, Push = 0.3 } }
-- Reared back, jaws wide, then a beam or a breath held on it.
local BREATH = { Wind = { Pitch = 0.3, Jaw = 0.8, Push = -0.15 }, Hit = { Pitch = -0.05, Jaw = 1.0, Push = -0.1 } }
-- Head down, then tossed up into it (horns, a skull, a snout).
local GORE = { Wind = { Pitch = -0.28, Lift = -0.1, Push = -0.15 }, Hit = { Pitch = 0.15, Push = 0.7, Jaw = 0.3 } }
-- Both claws (or blades, or ribbons) wide, then snapped shut together.
local SNIP = { Wind = { Arm = 1.4, Pitch = 0.1 }, Hit = { Arm = -0.3, Pitch = -0.15, Push = 0.35, Jaw = 0.3 } }
-- Drifting up, then sinking onto it.
local FLOAT = { Wind = { Lift = 0.3, Pitch = 0.1 }, Hit = { Lift = -0.15, Pitch = -0.2, Push = 0.4 } }
-- A beam fired on the wing: up on its wings, jaws wide.
local WINGBEAM = {
	Wind = { Pitch = 0.3, Lift = 0.25, Jaw = 0.8, Arm = 1.0 },
	Hit = { Pitch = -0.1, Jaw = 1.0, Arm = 0.3, Push = -0.1 },
}
local TAILLASH = { Wind = { Yaw = 0.5, Tail = -0.6 }, Hit = { Yaw = -0.7, Tail = 1.0, Push = 0.2 } }
local CRAWL = { Wind = { Lift = -0.2, Pitch = -0.1 }, Hit = { Lift = -0.1, Push = 0.6 } }
local HOP = { Wind = { Lift = -0.3 }, Hit = { Lift = 0.4, Push = 0.6 } }
-- Tanks
F.Clawtide = like("Bulwark", {
	-- Crusher Clamp: the crusher drawn up, then clamped down.
	Heavy = { Wind = { Arm = 1.5, Pitch = 0.15 }, Hit = { Arm = 0.2, Pitch = -0.15, Push = 0.3 }, OneArm = true },
	Lunge = F.Dreadcrown.Lunge,
	Guard = { Arm = 1.2, Lift = -0.15 },
})
F.Tuskmound = like("Carapace", {
	-- Tusk Swing: head (and trunk) swung across.
	Light = { Wind = { Yaw = 0.35, Pitch = 0.1, Jaw = 0.4 }, Hit = { Yaw = -0.45, Pitch = -0.15, Push = 0.35, Jaw = 0.6 } },
	-- Trample: reared right up, trunk high, then stamped down.
	Heavy = { Wind = { Pitch = 0.4, Lift = 0.25, Jaw = 0.8 }, Hit = { Pitch = -0.25, Lift = -0.2, Jaw = 0.4 } },
	Lunge = GORE,
	Cast = ROAR,
})
F.Steamhide = like("Bulwark", { Heavy = DROP, Cast = ROAR })
F.Hillback = like("Carapace", {
	Light = GORE,
	-- Landslide: its front heaved up, then the hill comes down.
	Heavy = { Wind = { Pitch = 0.3, Lift = 0.3 }, Hit = { Pitch = -0.15, Lift = -0.25, Push = 0.2 } },
	-- Boulder Roll: rocked back on its haunches, then rolled forward into it
	-- (a hill doesn't go over on its side).
	Lunge = { Wind = { Pitch = 0.15, Lift = 0.1, Push = -0.2 }, Hit = { Pitch = -0.3, Lift = -0.1, Push = 0.8 } },
})
F.Inkwrap = like("Carapace", {
	Light = { Wind = { Yaw = 0.3, Lift = 0.1 }, Hit = { Yaw = -0.4, Push = 0.3 } },
	-- Wrap: up on its tentacles, then down round it.
	Heavy = { Wind = { Lift = 0.3, Jaw = 0.5 }, Hit = { Lift = -0.2, Push = 0.4, Jaw = 0.8 } },
	-- Jet Lunge: squeezed low, then shot forward.
	Lunge = { Wind = { Lift = -0.3 }, Hit = { Lift = 0.2, Push = 0.8 } },
	Guard = { Lift = -0.35 },
})
F.Nullplate = like("Carapace", { Heavy = SPIN, Guard = F.Ironhide.Guard })
F.Tarrask = like("Carapace", { Light = GORE, Heavy = DROP, Lunge = GORE, Guard = F.Ironhide.Guard })
F.Gorebull = like("Carapace", {
	-- Horn Hook: head down and hooked up to one side.
	Light = { Wind = { Pitch = -0.2, Yaw = 0.3 }, Hit = { Pitch = 0.15, Yaw = -0.4, Push = 0.35 } },
	-- Bull Rush: head down, then a long charge.
	Heavy = { Wind = { Pitch = -0.3, Lift = -0.1, Push = -0.25 }, Hit = { Pitch = -0.2, Push = 0.9 } },
	Lunge = GORE,
	Cast = ROAR,
})
F.Yetihide = like("Bulwark", {
	-- Bear Hug: arms wide, then crushed shut round it.
	Heavy = { Wind = { Arm = 1.6, Pitch = 0.15, Jaw = 0.4 }, Hit = { Arm = 0.4, Pitch = -0.1, Push = 0.4, Jaw = 0.6 } },
	Lunge = F.Hulkshell.Lunge,
	Cast = ROAR,
})
F.Longneck = like("Carapace", {
	-- Neck Swing: the long neck swept across.
	Light = { Wind = { Yaw = 0.5, Tail = -0.5 }, Hit = { Yaw = -0.6, Tail = 0.8, Jaw = 0.3 } },
	Heavy = SPIN,
	-- Rear Up: up on its hind legs, then down.
	Lunge = { Wind = { Pitch = 0.45, Lift = 0.3 }, Hit = { Pitch = -0.25, Lift = -0.2, Push = 0.3 } },
	Cast = ROAR,
})
F.Barnacrab = like("Bulwark", { Heavy = DROP, Lunge = F.Dreadcrown.Lunge, Guard = { Lift = -0.35, Arm = 1.0 } })
-- Warriors
F.Crestbull = like("Bulwark", {
	Light = { Wind = { Pitch = -0.2, Yaw = 0.25 }, Hit = { Pitch = 0.2, Yaw = -0.35, Push = 0.35 } },
	Heavy = SPIN,
	Lunge = GORE,
	Cast = ROAR,
})
F.Rubbleking = like("Bulwark", { Heavy = SLAM, Lunge = BURST, Cast = ROAR })
F.Kickjaw = like("Razorback", {
	-- Drop Kick: up off the ground, then both feet into it.
	Heavy = { Wind = { Pitch = 0.35, Lift = 0.3, Tail = -0.4 }, Hit = { Pitch = -0.3, Lift = 0.1, Push = 0.7, Tail = 0.5 } },
})
F.Ogretoad = like("Bulwark", { Heavy = DROP, Lunge = HOP, Cast = ROAR })
F.Tritail = like("Scythe", {
	Light = TAILLASH,
	-- Triple Impale: all three tails drawn over, then driven down.
	Heavy = { Wind = { Pitch = 0.3, Tail = -0.9, Lift = 0.1 }, Hit = { Pitch = -0.35, Tail = 1.2, Push = 0.5 } },
	-- Tail Vault: vaulted up on its tails, then down on it.
	Lunge = { Wind = { Lift = -0.25 }, Hit = { Lift = 0.45, Pitch = -0.2, Push = 0.6 } },
	Cast = ROAR,
})
F.Ashcrawler = like("Razorback", { Light = TAILLASH, Heavy = BREATH, Lunge = CRAWL, Cast = ROAR })
F.Rancorn = like("Bulwark", {
	-- Grab: one long arm reached out and pulled in.
	Light = { Wind = { Arm = 1.2, Yaw = 0.2 }, Hit = { Arm = 0.3, Yaw = -0.3, Push = 0.4, Jaw = 0.4 }, OneArm = true },
	-- Jaw Slam: that great jaw thrown wide and slammed down.
	Heavy = { Wind = { Pitch = 0.35, Jaw = 1.0, Lift = 0.1 }, Hit = { Pitch = -0.35, Jaw = 0.2, Push = 0.4 } },
	Cast = ROAR,
})
F.Gashclaw = like("Scythe", {
	-- Disembowel: both blades high, then raked down through it.
	Heavy = { Wind = { Pitch = 0.25, Arm = 1.6, Lift = 0.1 }, Hit = { Pitch = -0.3, Arm = -0.6, Push = 0.5 } },
	Lunge = F.Razorback.Lunge,
})
F.Mossgiant = like("Bulwark", {
	-- Boulder Hurl: both arms back over its head, then thrown.
	Heavy = { Wind = { Pitch = 0.3, Arm = 1.6, Lift = 0.1 }, Hit = { Pitch = -0.2, Arm = 0.8, Push = 0.2 } },
	Lunge = F.Lankshade.Lunge,
	Cast = ROAR,
})
F.Blackhorn = like("Bulwark", {
	Light = GORE,
	-- Horn Lance: drawn back, then the horn driven through.
	Heavy = { Wind = { Pitch = 0.3, Push = -0.25 }, Hit = { Pitch = -0.4, Push = 0.75 } },
	Lunge = F.Hulkshell.Lunge,
	Cast = ROAR,
})
-- (Its jaw already hangs open over that belly: it gapes no wider than 0.7.)
F.Gluttonjaw = like("Razorback", {
	Light = { Wind = { Pitch = 0.15, Push = -0.25, Jaw = 0.6 }, Hit = { Pitch = -0.2, Push = 0.5, Jaw = -0.1 } },
	-- Pin and Chew: reared up, jaws wide, then down on it.
	Heavy = { Wind = { Pitch = 0.35, Jaw = 0.7, Lift = 0.15 }, Hit = { Pitch = -0.4, Jaw = 0.05, Lift = -0.15, Push = 0.5 } },
	Lunge = { Wind = { Pitch = 0.2, Lift = -0.15, Jaw = 0.65 }, Hit = { Pitch = -0.25, Push = 0.8, Jaw = 0 } },
	Cast = { Wind = { Pitch = 0.35, Jaw = 0.6, Arm = 0.6 }, Hit = { Pitch = -0.1, Jaw = 0.7, Arm = 0.3 } },
})
F.Lashape = like("Bulwark", {
	-- Whip: the tail drawn back and cracked across.
	Light = { Wind = { Tail = -0.8, Yaw = 0.3, Pitch = 0.1 }, Hit = { Tail = 1.2, Yaw = -0.4, Pitch = -0.1, Push = 0.2 } },
	Heavy = { Wind = { Tail = -1.0, Pitch = 0.3, Lift = 0.1 }, Hit = { Tail = 1.4, Pitch = -0.25, Push = 0.3 } },
	-- Ape Leap: a crouch on its knuckles, then a leap, arms up.
	Lunge = { Wind = { Lift = -0.3, Pitch = 0.1, Arm = 0.6 }, Hit = { Lift = 0.4, Pitch = -0.2, Push = 0.7, Arm = 1.2 } },
	Cast = ROAR,
})
-- Ranged
F.Shrieker = like("Razorback", FLYER)
F.Shrieker.Heavy = WINGBEAM
F.Tonguefrost = like("Razorback", {
	-- Tongue Whip: mouth open, the tongue lashed out.
	Light = { Wind = { Pitch = 0.1, Jaw = 0.6, Push = -0.15 }, Hit = { Pitch = -0.15, Jaw = 0.9, Push = 0.3 } },
	-- Tongue Pull: shot out, then hauled back in.
	Heavy = { Wind = { Jaw = 1.0, Push = 0.2 }, Hit = { Jaw = 0.3, Push = -0.4, Pitch = 0.15 } },
	Lunge = F.Voltfin.Lunge,
})
F.Glidespine = like("Razorback", {
	Light = { Wind = { Yaw = 0.3, Arm = 0.4 }, Hit = { Yaw = -0.4, Push = 0.2, Arm = 0.8 } },
	-- Glide Slam: up on its flaps, then down onto it.
	Heavy = { Wind = { Lift = 0.4, Pitch = 0.2, Arm = 1.0 }, Hit = { Lift = -0.25, Pitch = -0.3, Push = 0.5 } },
	Lunge = FLYER.Lunge,
})
F.Fathomweb = like("Razorback", { Heavy = F.Thornlob.Heavy, Lunge = F.Thornlob.Lunge, Guard = F.Thornlob.Guard })
F.Spitgill = like("Razorback", { Heavy = BREATH, Lunge = F.Voltfin.Lunge })
F.Oculus = like("Razorback", {
	-- Eye Flash: its lid thrown open.
	Light = { Wind = { Jaw = 0.8, Lift = 0.1 }, Hit = { Jaw = 1.0, Push = -0.05 } },
	Heavy = DROP,
	Lunge = FLOAT,
	Cast = { Wind = { Lift = 0.25, Jaw = 0.9, Arm = 0.8 }, Hit = { Jaw = 1.0, Arm = 0.3 } },
	-- Tipped on edge, lid down.
	Guard = { Lift = -0.15, Roll = 0.25 },
})
F.Quillhorn = like("Razorback", {
	Light = { Wind = { Pitch = 0.1, Yaw = 0.3 }, Hit = { Pitch = -0.1, Yaw = -0.4, Push = 0.15 } },
	Heavy = GORE,
	Lunge = F.Thornlob.Lunge,
})
F.Phasehorn = like("Razorback", {
	Light = GORE,
	Heavy = BREATH,
	-- Phase Step: gone and back, a step on.
	Lunge = { Wind = { Lift = -0.2 }, Hit = { Push = 0.9 } },
})
F.Lightbird = like("Razorback", FLYER)
F.Lightbird.Heavy = WINGBEAM
F.Pulsewing = like("Razorback", FLYER)
-- EMP Shriek: wings up, a shriek.
F.Pulsewing.Heavy = { Wind = { Lift = 0.2, Arm = 1.2, Jaw = 0.8 }, Hit = { Lift = -0.1, Arm = 0.2, Jaw = 1.0 } }
-- Assassins
F.Duskbat = like("Razorback", FLYER)
F.Duskbat.Heavy = F.Nightwing.Heavy
F.Tendrilis = like("Scythe", {
	Light = { Wind = { Tail = -0.6, Pitch = 0.1 }, Hit = { Tail = 0.9, Pitch = -0.15, Push = 0.3 } },
	-- Spear Lunge: drawn back, then the spear of a head driven in.
	Heavy = { Wind = { Pitch = 0.25, Push = -0.3, Tail = -0.8 }, Hit = { Pitch = -0.4, Push = 0.8, Tail = 0.6 } },
})
F.Snipclaw = like("Scythe", { Heavy = SNIP, Lunge = F.Nulltalon.Lunge })
F.Needlewing = like("Razorback", FLYER)
-- Tail Drill: up on its wings, its needle swung under and driven in.
F.Needlewing.Heavy = { Wind = { Pitch = 0.3, Lift = 0.3, Tail = -0.8, Arm = 1.0 }, Hit = { Pitch = -0.3, Tail = 1.2, Push = 0.6 } }
F.Needlewing.Lunge = { Wind = { Lift = 0.2, Arm = 1.2 }, Hit = { Push = 1.0, Arm = 0.6 } }
F.Hollowbone = like("Scythe", { Heavy = BREATH, Lunge = F.Lankshade.Lunge })
F.Ribbonarm = like("Scythe", {
	Light = { Wind = { Yaw = 0.4, Arm = 1.4 }, Hit = { Yaw = -0.5, Arm = -0.3, Push = 0.3 }, OneArm = true },
	Heavy = SNIP,
	-- Ribbon Pierce: both ribbons drawn back, then thrust through.
	Lunge = { Wind = { Pitch = 0.1, Arm = 1.6 }, Hit = { Pitch = -0.3, Arm = 1.2, Push = 0.8 } },
})
F.Dunemaw = like("Razorback", {
	Light = F.Dreadmaw.Light,
	Heavy = BURST,
	-- Burrow Rush: down into the ground and along under it.
	Lunge = { Wind = { Lift = -0.5, Pitch = -0.2 }, Hit = { Lift = -0.2, Push = 0.9 } },
	Cast = ROAR,
	Guard = { Lift = -0.5 },
})
F.Lashlight = like("Scythe", {
	Light = { Wind = { Arm = 1.6, Yaw = 0.3 }, Hit = { Arm = -0.2, Yaw = -0.4, Push = 0.2 }, OneArm = true },
	-- Twin Lash: both whips up, then cracked down.
	Heavy = { Wind = { Arm = 1.6, Pitch = 0.2 }, Hit = { Arm = -0.4, Pitch = -0.2, Push = 0.3 } },
})
F.Inkstalk = like("Scythe", {
	Light = { Wind = { Arm = 1.0, Pitch = 0.1 }, Hit = { Arm = -0.2, Push = 0.35 }, OneArm = true },
	Heavy = F.Inkwrap.Heavy,
	Lunge = F.Inkwrap.Lunge,
})
F.Skyrazor = like("Razorback", { Light = F.Razorclaw.Light, Heavy = FLYER.Heavy, Lunge = FLYER.Lunge, Cast = FLYER.Cast })
F.Thornlash = like("Scythe", {
	-- Spine Volley: both tails drawn over, then flung.
	Heavy = { Wind = { Tail = -0.9, Pitch = 0.25 }, Hit = { Tail = 1.3, Pitch = -0.1, Push = 0.1 } },
	Lunge = { Wind = { Tail = -0.6, Lift = -0.15 }, Hit = { Tail = 1.0, Push = 0.7 } },
})
F.Flickerstripe = like("Scythe", {
	Light = { Wind = { Arm = 1.2, Pitch = 0.1 }, Hit = { Arm = -0.3, Pitch = -0.2, Push = 0.3 }, OneArm = true },
	-- Shrink Ray: both hands up, then thrust out at it.
	Heavy = { Wind = { Arm = 1.6, Jaw = 0.6, Pitch = 0.15 }, Hit = { Arm = 1.4, Jaw = 0.9, Push = -0.1 } },
	Lunge = F.Nulltalon.Lunge,
})
-- Breakers
F.Frostmaw = like("Bulwark", { Heavy = BREATH, Lunge = F.Hulkshell.Lunge, Cast = ROAR })
F.Hivecrystal = like("Carapace", { Heavy = BREATH, Lunge = { Wind = { Lift = -0.15 }, Hit = { Push = 0.7 } } })
F.Peelcroc = like("Razorback", { Light = F.Dreadmaw.Light, Heavy = F.Dreadmaw.Heavy, Lunge = F.Dreadmaw.Lunge, Cast = ROAR })
F.Magnetjaw = like("Bulwark", {
	-- Magnet Pull: pincers forward, then hauled back.
	Heavy = { Wind = { Pitch = -0.2, Arm = 1.4, Push = 0.15 }, Hit = { Pitch = 0.2, Arm = 0.5, Push = -0.35 } },
	Lunge = GORE,
})
F.Cleaverhead = like("Bulwark", {
	Light = F.Bladebrow.Light,
	-- Head Cleave: reared up, then the blade of a head brought down.
	Heavy = { Wind = { Pitch = 0.4, Lift = 0.1, Arm = 1.2 }, Hit = { Pitch = -0.45, Push = 0.5, Arm = 0.4 } },
	Lunge = F.Bladebrow.Lunge,
})
F.Starcrop = like("Bulwark", {
	Light = { Wind = { Pitch = 0.15, Jaw = 0.5 }, Hit = { Pitch = -0.25, Push = 0.4, Jaw = 0 } },
	-- Belly Gulp: wings wide, the star on its belly drawing it in.
	Heavy = { Wind = { Pitch = -0.2, Lift = 0.1, Arm = 1.4 }, Hit = { Pitch = 0.15, Push = -0.3, Arm = 0.4 } },
	Cast = ROAR,
})
F.Drillmole = like("Bulwark", {
	Light = F.Drillhorn.Light,
	Heavy = BURST,
	-- Dig In: down, then driving forward drill first.
	Lunge = { Wind = { Lift = -0.3, Pitch = -0.2 }, Hit = { Push = 0.8, Jaw = 0.6 } },
})
F.Gulper = like("Bulwark", {
	-- Shoulder Swallow: the shoulder maw thrown open and down over it.
	Heavy = { Wind = { Pitch = 0.3, Jaw = 1.1, Yaw = 0.3 }, Hit = { Pitch = -0.3, Jaw = 0.1, Push = 0.4, Yaw = -0.2 } },
	Lunge = F.Hulkshell.Lunge,
	-- A shot from its cannon arm, with the recoil.
	Cast = { Wind = { Arm = 1.2, Pitch = 0.1 }, Hit = { Arm = 1.4, Push = -0.3 } },
})
-- Wardens
F.Prisma = like("Razorback", {
	-- Lance Beam: it rises, its band tilting open.
	Light = { Wind = { Lift = 0.2, Jaw = 0.4 }, Hit = { Lift = 0.05, Jaw = 0.8, Push = -0.05 } },
	Heavy = BREATH,
	Lunge = FLOAT,
	Cast = F.Skyjelly.Cast,
	-- A facet turned to it.
	Guard = { Lift = 0.15, Roll = 0.4, Jaw = 0.3 },
})
F.Capspore = like("Carapace", {
	Light = GORE,
	Heavy = F.Sporeback.Heavy,
	-- Waddle: rocking side to side forward.
	Lunge = { Wind = { Roll = 0.2 }, Hit = { Roll = -0.2, Push = 0.4 } },
	Cast = F.Skyjelly.Cast,
	Guard = F.Sporeback.Guard,
})
F.Coinmaw = like("Carapace", {
	Light = F.Dreadmaw.Light,
	-- Coin Spit: the purse thrown open, then a coin spat out.
	Heavy = { Wind = { Jaw = 0.7, Pitch = 0.2 }, Hit = { Jaw = 0.35, Pitch = -0.1, Push = -0.15 } },
	Lunge = HOP,
})
F.Silkling = like("Carapace", {
	Light = GORE,
	Heavy = BREATH,
	-- Inch Forward: its front lifted, then set down further on.
	Lunge = { Wind = { Pitch = 0.15, Lift = 0.1 }, Hit = { Pitch = -0.15, Push = 0.4 } },
})
F.Pipsqueak = like("Carapace", {
	-- Bonk: up on its toes, then head first.
	Light = { Wind = { Pitch = 0.25, Lift = 0.1 }, Hit = { Pitch = -0.3, Push = 0.35 } },
	-- Trip: low, then rolled into its legs.
	Heavy = { Wind = { Lift = -0.2, Roll = 0.2 }, Hit = { Lift = 0.1, Roll = -0.4, Push = 0.4 } },
	Lunge = { Wind = { Lift = -0.15 }, Hit = { Lift = 0.2, Push = 0.6 } },
	Cast = F.Skyjelly.Cast,
})
F.Shadowsphere = like("Razorback", {
	-- Shadow Snap: the maw in its shadow snapping.
	Light = { Wind = { Jaw = 0.6, Lift = 0.15 }, Hit = { Jaw = 1.0, Lift = -0.1, Push = 0.3 } },
	Heavy = { Wind = { Lift = 0.35, Jaw = 0.4 }, Hit = { Lift = -0.3, Jaw = 1.0, Push = 0.3 } },
	Lunge = FLOAT,
	Cast = F.Skyjelly.Cast,
	Guard = { Lift = 0.2 },
})
F.Twinsong = like("Bulwark", {
	-- Twin Chop: both arms at once, both heads snapping.
	Light = { Wind = { Arm = 1.2, Pitch = 0.1, Jaw = 0.3 }, Hit = { Arm = -0.3, Pitch = -0.15, Push = 0.3, Jaw = 0.5 } },
	Heavy = BREATH,
	Lunge = { Wind = { Lift = -0.15 }, Hit = { Push = 0.6, Lift = 0.05 } },
})
F.Lumeballoon = like("Razorback", {
	Light = FLOAT,
	-- Red Mist: drawn in, then swelling out (on its stilts: it barely sinks,
	-- or its feet would go through the ground).
	Heavy = { Wind = { Lift = -0.06, Pitch = 0.1, Jaw = 0.4 }, Hit = { Lift = 0.3, Jaw = 0.9 } },
	Lunge = FLOAT,
	Cast = { Wind = { Lift = -0.06, Jaw = 0.4 }, Hit = { Lift = 0.4, Jaw = 0.9 } },
	Guard = { Lift = -0.05, Pitch = 0.1, Jaw = 0.2 },
})

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

-- Out past 1 and back (0 -> ~1.1 -> 1): a blow carried through.
local function backOut(t: number): number
	t = math.clamp(t, 0, 1) - 1
	local s = Motion.Overshoot
	return 1 + t * t * ((s + 1) * t + s)
end

local CASTS = { Bolt = true, Nova = true, Cast = true }

-- A wild kaiju's day (KaijuWilds: KaijuMood, from KaijuMoodAt): head down
-- sniffing the ground, looking about, lying down, asleep (lower, curled),
-- or a roar (rearing, jaws wide); Cower, backing off from a HYPERBEAM
-- winding up; and Bound, held by a tame, struggling
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
	Cower = function(pose, t, k)
		-- Cowed by a HYPERBEAM winding up: crouched low, head down and
		-- drawn back, tail tucked, shaking.
		pose.Lift -= 0.3 * k
		pose.Pitch -= 0.2 * k
		pose.Tail -= 0.45 * k
		pose.Arm -= 0.15 * k
		pose.Yaw += math.sin(t * 23) * 0.05 * k
		pose.Roll += math.sin(t * 29 + 1) * 0.04 * k
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
			-- Into the wind-up, through the blow (a touch past it), held as
			-- it lands, and back.
			local wind, hit = 0, 0
			local landed = at + Motion.Strike + Motion.Hold
			local building = -1
			if now >= start and now < at then
				building = (now - start) / math.max(at - start, 0.01)
				wind = ease(building)
			elseif now >= at and now < at + Motion.Strike then
				local p = (now - at) / Motion.Strike
				hit = backOut(p)
				wind = math.max(0, 1 - hit) -- (crossfaded: the two never stack)
			elseif now >= at + Motion.Strike and now < landed then
				hit = 1
			elseif now >= landed and now < landed + Motion.Settle then
				hit = 1 - ease((now - landed) / Motion.Settle)
			end
			add(pose, key.Wind, wind, side)
			add(pose, key.Hit, hit, side)
			if key.OneArm then
				pose.ArmSide = side
			end
			if building >= 0 then
				local cast = CASTS[ALIASES[kind] or kind] == true
				if cast then
					-- Gathering its power: a tremble that builds, swelling a little.
					local k = building * building
					pose.Roll += math.sin(now * 47) * 0.035 * k
					pose.Pitch += math.sin(now * 39 + 1) * 0.025 * k
					pose.Lift += 0.06 * k + math.sin(now * 31) * 0.015 * k
				elseif kind == "Heavy" and building > 0.7 then
					-- Coiled at the top, straining, just before it comes down.
					local k = (building - 0.7) / 0.3
					pose.Roll += math.sin(now * 55) * 0.03 * k
					pose.Pitch += math.sin(now * 61 + 2) * 0.02 * k
				end
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
		-- Snapped back at once, then easing out: the blow lands on it.
		local k = if hurt < 0.03 then hurt / 0.03 else (1 - (hurt - 0.03) / 0.22) ^ 2
		pose.Pitch += 0.16 * k
		pose.Roll += 0.1 * (a.HurtSide or 1) * k
		pose.Lift -= 0.06 * k
		pose.Push -= 0.12 * k
	end
	return pose
end

-- How its whole body moves as it walks, on top of its pose (CreatureAnimation
-- adds it each frame): its weight dips onto each foot as it lands and rolls
-- from side to side, it leans into a run and twists against its stride,
-- and it banks into a turn (`turn`: radians a second, + to its left). At
-- rest it breathes and shifts its weight. `phase` and `amount` are its
-- walk's (Motion.angles). Mutates and returns `pose`.
function Motion.gait(pose, phase: number, amount: number, now: number, turn: number)
	local step = math.abs(math.sin(phase)) -- 0 as a foot lands, 1 mid-stride
	pose.Lift += (step - 0.55) * 0.14 * amount
	pose.Roll += math.sin(phase) * 0.07 * amount
	pose.Pitch -= 0.09 * amount + (1 - step) * 0.025 * amount
	pose.Yaw += math.sin(phase) * 0.06 * amount
	pose.Tail -= math.sin(phase) * 0.2 * amount
	local bank = math.clamp(turn, -3, 3)
	pose.Roll += bank * 0.07 * (0.35 + amount)
	pose.Yaw += bank * 0.05
	local still = 1 - amount
	pose.Roll += math.sin(now * 0.7) * 0.02 * still
	pose.Lift += math.sin(now * 2.1) * 0.015 * still
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
-- legs keep upright as it rears or leans; a flyer's wings beat with its
-- arms, and a many-headed kind's heads snap in with its jaw. Returns x, y,
-- z, lift, push.
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
	elseif kind == "Wing" then
		return x, y, z + side * pose.Arm * 0.45, 0, 0 -- (a wingbeat)
	elseif kind == "Head" then
		return x - pose.Jaw * 0.3, y + pose.Yaw * 0.3, z, 0, 0 -- (a head snaps in on a bite)
	end
	return x, y, z, 0, 0
end

--- A jump after its owner (KaijuServer's follow-the-leader hops), on top of
--- its pose: `t` seconds from take-off (negative while it's still crouching
--- for it), `air` seconds in the air. It crouches, springs up stretched with
--- its nose up and its legs tucked, tips forward to come down, and squashes
--- as it lands. Mutates and returns `pose`.
Motion.Jump = { Crouch = 0.12, Spring = 0.05, Land = 0.22 }

function Motion.hop(pose, t: number, air: number)
	local jump = Motion.Jump
	if t < -jump.Crouch or t >= air + jump.Land then
		return pose
	end
	local crouch = 0
	if t < 0 then
		crouch = (1 + t / jump.Crouch) ^ 2
	elseif t < jump.Spring then
		crouch = 1 - t / jump.Spring -- (springing out of it)
	end
	pose.Lift -= 0.3 * crouch
	pose.Pitch -= 0.1 * crouch
	pose.Tail += 0.2 * crouch
	if t >= 0 and t < air then
		local p = t / air
		local up = math.min(1, t / jump.Spring)
		local arc = math.sin(p * math.pi)
		pose.Lift += 0.15 * up * math.max(0, 1 - p / 0.35)
		pose.Pitch += up * (0.28 * (1 - p) - 0.18 * p)
		pose.Arm += 0.7 * arc
		pose.Tail -= 0.35 * arc
	elseif t >= air then
		local k = (1 - (t - air) / jump.Land) ^ 2
		pose.Lift -= 0.28 * k
		pose.Pitch -= 0.18 * k
	end
	return pose
end

return Motion
