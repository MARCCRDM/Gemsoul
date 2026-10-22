--[[
	Walking into a rock mines it, just as a click or a tap on it does: on
	foot and in a mech, on a computer, a phone or a pad. Push against a rock
	and the pick (or the mech's drill) keeps swinging at it, paced by the
	swing's own cooldown; walk past or back away and it stops.
	(Client.OutpostScene: the Outpost's rocks and the Rift's healing
	crystals; Client.MineScene: an expedition's wall; Client.VehicleDrive:
	the rock a mech's hull is shoving.)

	  WalkMine.Touch    studs from a rock's side your middle can be and still
	                    be up against it, on foot
	  WalkMine.Facing   how square on you must be heading into it: the dot of
	                    where you're heading and the way to it
	  WalkMine.Every    seconds between looks
	  WalkMine.Shove    seconds a mech still counts as shoving a rock after
	                    its hull last stopped against it
	  WalkMine.Push     how hard a mech's pilot must be pushing (-1..1 throttle)

	  WalkMine.against(at, heading, body, size, touch?) -> boolean
	      are you, at `at` and heading `heading` (flat; a move direction, any
	      length, zero when you stand still), pushing into the box `size` at
	      `body`? Not standing still, not from on top of it, not walking past
	      or backing away.
]]
local WalkMine = {}

WalkMine.Touch = 2.6
WalkMine.Facing = 0.35
WalkMine.Every = 0.1
WalkMine.Shove = 0.3
WalkMine.Push = 0.3

-- The least you must be heading anywhere (a stick's dead zone).
local MOVING = 0.1

function WalkMine.against(at: Vector3, heading: Vector3, body: CFrame, size: Vector3, touch: number?): boolean
	local flatHeading = Vector3.new(heading.X, 0, heading.Z)
	if flatHeading.Magnitude < MOVING then
		return false
	end
	local half = size / 2
	local rel = body:PointToObjectSpace(at)
	-- (on top of it: walking about up there isn't pushing into it)
	if rel.Y > half.Y + 0.5 then
		return false
	end
	-- The nearest point of its sides to you, flat.
	local nearest = body:PointToWorldSpace(
		Vector3.new(math.clamp(rel.X, -half.X, half.X), rel.Y, math.clamp(rel.Z, -half.Z, half.Z))
	)
	local gap = Vector3.new(nearest.X - at.X, 0, nearest.Z - at.Z)
	local distance = gap.Magnitude
	if distance > (touch or WalkMine.Touch) then
		return false
	end
	if distance < 1e-3 then
		-- (inside its footprint: you're in it, so you're pushing into it)
		return true
	end
	return flatHeading.Unit:Dot(gap / distance) >= WalkMine.Facing
end

return WalkMine
