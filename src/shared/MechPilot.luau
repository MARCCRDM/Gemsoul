-- Who pilots which Outpost mech, for the server and every client alike, and
-- how a mech moves over the ground.
--
-- No Roblox seats. The server makes you a mech's pilot: your MechPilot
-- attribute is its MechId, its MechPilotId is your UserId, and a weld holds
-- you in its cockpit (Server OutpostVehicles). Attributes replicate to every
-- client, so each side knows who pilots what without working it out from a
-- seat. Your own screen drives the mech (Client VehicleDrive, with
-- MechPilot.move below), and the server checks where it went and passes it on.
local CollectionService = game:GetService("CollectionService")

local MechPilot = {}

MechPilot.Tag = "OutpostMech"
-- Studs kept clear of a wall; the highest step a mech climbs (times its
-- scale: its hull starts this high); how far below it looks for the ground.
MechPilot.Skin, MechPilot.Lift, MechPilot.Drop = 0.4, 1.6, 60
-- Ground it walks over rather than into: a surface whose normal points up
-- at least Walkable (60 degrees and gentler: the biomes' hummocks, ridges,
-- drifts and cones, ramps), however far it rises under the hull's front,
-- the hull lifted over it up to Climb studs (times its scale) at a time.
-- Down a slope that steep it keeps to the ground. A move is taken in steps
-- of at most Stride studs, so a slow frame's long move up a slope never
-- reads as a ledge.
MechPilot.Walkable, MechPilot.Climb, MechPilot.Stride = 0.5, 8, 1
-- (The steepest slope it walks, rise over run.)
MechPilot.Grade = math.sqrt(1 - MechPilot.Walkable ^ 2) / MechPilot.Walkable

-- The MechId of the mech `player` pilots, if any.
function MechPilot.of(player: Player?): string?
	local id = player and player:GetAttribute("MechPilot")
	return if type(id) == "string" and id ~= "" then id else nil
end

-- A mech by its MechId (nil while it isn't here: streaming).
function MechPilot.find(id: string?): Model?
	if not id then
		return nil
	end
	for _, model in CollectionService:GetTagged(MechPilot.Tag) do
		if model:GetAttribute("MechId") == id then
			return model
		end
	end
	return nil
end

-- The mech `player` pilots, if it's here.
function MechPilot.mech(player: Player?): Model?
	return MechPilot.find(MechPilot.of(player))
end

-- Its kind (Shared.Outpost.Machines).
function MechPilot.kind(model: Instance?): string?
	local kind = model and model:GetAttribute("MechKind")
	return if type(kind) == "string" then kind else nil
end

-- A mech's state for moving it, from its model as it stands:
--   Position, Yaw   where its chassis is and which way it faces
--   Speed           studs a second along its heading (backwards if negative)
--   Fall            how fast it's falling, studs a second
--   Lift            the highest step it climbs
--   Scale           its size (MechScale)
--   Hover           how high its chassis's middle rides over the ground
--   HullOffset, HullSize   its hull (what it bumps into), from the chassis
--   Through         true: what's in its way doesn't stop it (pushing out)
function MechPilot.state(model: Model): any
	local chassis = model.PrimaryPart :: BasePart
	local hull = model:FindFirstChild("Hull") :: BasePart?
	local scale = model:GetAttribute("MechScale") or 1
	local at = chassis.CFrame.Position
	local _, yaw = chassis.CFrame:ToOrientation()
	local flat = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	return {
		Position = at,
		Yaw = yaw,
		Speed = 0,
		Fall = 0,
		Lift = MechPilot.Lift * scale,
		Scale = scale,
		Hover = chassis.Size.Y / 2 + 0.2,
		HullOffset = if hull then flat:ToObjectSpace(hull.CFrame) else CFrame.new(0, MechPilot.Lift * scale / 2, 0),
		HullSize = if hull
			then hull.Size - Vector3.new(0.2, 0.2, 0.2)
			else chassis.Size - Vector3.new(0, MechPilot.Lift * scale, 0),
		Through = false,
	}
end

-- Where its chassis goes.
function MechPilot.frame(mech): CFrame
	return CFrame.new(mech.Position) * CFrame.Angles(0, mech.Yaw, 0)
end

-- Its hull swept `length` studs along `along`: how far it gets, and what
-- stops it. Ground it can walk up (Walkable) doesn't: the hull's swept again
-- lifted clear of it, and of the slope rising on over the rest of the way,
-- up to Climb studs; a wall (or ground steeper than that) does.
local function sweep(mech, world, along: Vector3, length: number): (number?, string?)
	local from = MechPilot.frame(mech) * mech.HullOffset
	local limit = MechPilot.Climb * (mech.Scale or 1)
	local lifted = 0
	local hit, what
	for _ = 1, 4 do
		local start = if lifted > 0 then from + Vector3.new(0, lifted, 0) else from
		local normal, point
		hit, what, normal, point = world.Sweep(start, mech.HullSize, along * length)
		if not hit then
			return nil, nil
		end
		if not (normal and point and normal.Y >= MechPilot.Walkable) then
			return hit, what
		end
		local bottom = start.Position.Y - mech.HullSize.Y / 2
		local grade = math.sqrt(math.max(0, 1 - normal.Y * normal.Y)) / normal.Y
		lifted += math.max(point.Y - bottom + grade * math.max(0, length - hit), 0) + 0.05
		if lifted > limit then
			return hit, what
		end
	end
	-- (Still finding slope after all that: it's ground all the way.)
	return nil, nil
end

-- One step of a move (at most Stride studs).
local function step(mech, world, distance: number, yaw: number, dt: number): string?
	local here = mech.Position
	local heading = CFrame.Angles(0, yaw, 0)
	local to = here
	local blocked: string? = nil
	if math.abs(distance) > 1e-4 then
		local along = heading.LookVector * math.sign(distance)
		local free = math.abs(distance)
		if not mech.Through then
			local hit, what = sweep(mech, world, along, free + MechPilot.Skin)
			if hit then
				free = math.clamp(hit - MechPilot.Skin, 0, free)
				blocked = what or "something"
			end
		end
		to = here + along * free
		local rim = world.Rim
		if rim then
			local offset = to - rim.Center
			if Vector3.new(offset.X, 0, offset.Z).Magnitude > rim.Radius then
				to, blocked = here, "the crater rim"
			end
		end
	end
	local foot = here.Y - mech.Hover
	local function groundAt(at: Vector3): number?
		local y = world.Floor(Vector3.new(at.X, foot + mech.Lift + 0.5, at.Z), mech.Lift + 0.5 + MechPilot.Drop)
		return if y then y + mech.Hover else nil
	end
	local rest = groundAt(to)
	if to ~= here and rest and rest > here.Y + mech.Lift + 0.05 then
		to, blocked = here, "a ledge"
		rest = groundAt(here)
	end
	local y = here.Y
	if rest and rest >= y then
		y, mech.Fall = rest, 0
	elseif rest and mech.Fall == 0 and y - rest <= (to - here).Magnitude * MechPilot.Grade + 0.05 then
		-- Down ground it walks: it keeps to it (no hop at every step).
		y = rest
	elseif rest then
		mech.Fall += (world.Gravity or 196.2) * dt
		y = math.max(rest, y - mech.Fall * dt)
		if y <= rest then
			mech.Fall = 0
		end
	end
	mech.Position, mech.Yaw = Vector3.new(to.X, y, to.Z), yaw
	return blocked
end

-- One frame's move: `distance` studs along heading `yaw` (backwards if
-- negative), over the ground of `world` = {
--   Sweep(from, size, direction) -> (distance?, what?, normal?, point?)
--                                     its hull swept ahead: how far to what,
--                                     and the surface it met (its normal, and
--                                     where)
--   Floor(origin, length) -> height?  the ground below a point
--   Rim = { Center, Radius }          never past this
--   Gravity
-- }. It stops short of what's in its way, walks up and down ground no
-- steeper than Walkable, steps up anything up to its Lift, won't climb
-- higher, and falls off a drop. No ground found at all, it keeps its height
-- (the ground may still be loading in). Taken in steps of at most Stride
-- studs. Returns what stopped it, if anything.
function MechPilot.move(mech, world, distance: number, yaw: number, dt: number): string?
	local steps = math.max(1, math.ceil(math.abs(distance) / MechPilot.Stride))
	for _ = 1, steps do
		local blocked = step(mech, world, distance / steps, yaw, dt / steps)
		if blocked then
			return blocked
		end
	end
	return nil
end

return MechPilot
