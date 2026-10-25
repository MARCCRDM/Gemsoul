--[[
	How a blow you land feels (pure numbers; Combat's Contact handler plays
	them): how long the swing stops dead as the blade bites (hit stop), how
	hard your view is jarred and which way (with the cut), how big the spark,
	the flash on what you hit, the sound and the rumble in a controller.

	  SwordFeel.tune(info, side) -> feel
	    info = { Heavy, Crit, Blocked, Kill, Combo } (the server's Contact)
	    side = "Right" | "Left" (the swing's side: a right cut crosses your
	           view leftward, a left one rightward; a heavy chops down)
	    feel = {
	      Stop      seconds the swing holds as the blade bites
	      Strength  how hard the blade shudders as it holds (0..~2)
	      Pitch, Yaw, Roll, KickFor   the jar of your view (radians, seconds)
	      Cut       Vector3-free: { X, Y } the cut across your view (X + to
	                your right, Y + up), for the spark's streak
	      Power     the spark's size (1 a cut)
	      Flash     the hit flash's strength on what you hit (0: none)
	      Sound     "Contact", "HeavyContact" or "Deflect"; SoundPitch
	      Rumble    controller rumble (0..1) and RumbleFor (seconds)
	    }

	Every step of a combo lands a little harder; a crit and a kill harder
	still; a blow turned on a guard stops short and rings off it.
]]
local SwordFeel = {}

SwordFeel.Stop = { Light = 0.065, Heavy = 0.1, Blocked = 0.05, Most = 0.17 }
SwordFeel.Kick = { Light = 0.014, Heavy = 0.032 }

function SwordFeel.tune(info, side: string?)
	info = info or {}
	local heavy = info.Heavy == true
	local blocked = info.Blocked == true
	local combo = math.clamp(tonumber(info.Combo) or 1, 1, 6)
	-- Each step of a combo hits a little harder (to a third more).
	local build = 1 + math.min(0.33, (combo - 1) * 0.11)
	local punch = build * (if info.Crit then 1.4 else 1) * (if info.Kill then 1.5 else 1)
	local stop = if blocked then SwordFeel.Stop.Blocked
		elseif heavy then SwordFeel.Stop.Heavy
		else SwordFeel.Stop.Light
	if not blocked then
		stop += (combo - 1) * 0.008 + (if info.Crit then 0.025 else 0) + (if info.Kill then 0.05 else 0)
	end
	stop = math.min(stop, SwordFeel.Stop.Most)
	-- Which way the cut crosses your view: a right-hand cut sweeps leftward,
	-- a backhand rightward, a heavy straight down.
	local across = if side == "Left" then 1 else -1
	local cut = if heavy then { X = 0.25 * across, Y = -1 } else { X = across, Y = -0.35 }
	local kick = (if heavy then SwordFeel.Kick.Heavy else SwordFeel.Kick.Light) * punch
	local feel = {
		Stop = stop,
		Strength = (if blocked then 0.6 elseif heavy then 1.4 else 1) * math.min(punch, 1.8),
		-- The view follows the blade a touch as it meets its mark: down with
		-- a chop, across with a cut.
		Pitch = if heavy then -kick else -kick * 0.35,
		Yaw = if heavy then 0 else -across * kick,
		Roll = (if heavy then 0.15 else 0.45) * across * kick,
		KickFor = (if heavy then 0.3 else 0.2) * (if info.Kill then 1.3 else 1),
		Cut = cut,
		Power = (if heavy then 1.35 else 1) * (if info.Crit then 1.25 else 1) * (if info.Kill then 1.2 else 1),
		Flash = if blocked then 0 else (if heavy or info.Crit then 1.5 else 1),
		Sound = if blocked then "Deflect" elseif heavy or info.Kill then "HeavyContact" else "Contact",
		SoundPitch = 1 + (combo - 1) * 0.05,
		Rumble = if blocked then 0.25 elseif heavy or info.Kill then 0.8 else 0.45,
		RumbleFor = if heavy or info.Kill then 0.14 else 0.08,
	}
	if blocked then
		-- Turned aside: a short jolt back at you, not a follow-through.
		feel.Pitch, feel.Yaw, feel.Roll = 0.008, across * 0.006, 0
		feel.KickFor = 0.16
	end
	return feel
end

return SwordFeel
